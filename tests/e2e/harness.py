"""Pseudo-terminal harness for munin end-to-end tests.

Runs a built example binary on a real pty, feeds it keystrokes and signals,
and captures everything it writes back - escape sequences included. That is
the only way to check the parts of a TUI framework that unit tests cannot
reach: terminal setup and teardown, alternate screen handling, input parsing
of real byte sequences, and restoring the terminal when the process dies.

Standard library only - no pytest, no pexpect.
"""

import errno
import fcntl
import os
import pty
import re
import signal
import struct
import subprocess
import sys
import termios
import threading
import time

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# MUNIN_BIN lets CI (or a bisect) point the suite at a different build.
BIN_DIR = os.environ.get("MUNIN_BIN") or os.path.join(REPO_ROOT, "bin")

# CSI / OSC / DCS and friends, plus single-character escapes.
ANSI_RE = re.compile(
    rb"\x1b\[[0-?]*[ -/]*[@-~]"  # CSI
    rb"|\x1b[]PX^_].*?(?:\x07|\x1b\\)"  # OSC/DCS/SOS/PM/APC
    rb"|\x1b[@-Z\\-_]"  # two-byte escapes
)


def strip_ansi(data: bytes) -> str:
    """Visible text only, for assertions about what the user would see."""
    return ANSI_RE.sub(b"", data).decode("utf-8", errors="replace")


def _cell_width(ch: str) -> int:
    """Terminal cells a character occupies (mirrors munin's width table)."""
    o = ord(ch)
    if o < 0x1100:
        return 1
    wide = (
        (0x1100, 0x115F), (0x2329, 0x232A), (0x2E80, 0x303F), (0x3040, 0xA4CF),
        (0xAC00, 0xD7A3), (0xF900, 0xFAFF), (0xFE10, 0xFE19), (0xFE30, 0xFE6F),
        (0xFF00, 0xFF60), (0xFFE0, 0xFFE6), (0x1F300, 0x1F64F), (0x1F680, 0x1F6FF),
        (0x1F900, 0x1F9FF), (0x1FA70, 0x1FAFF), (0x20000, 0x2FFFF),
    )
    return 2 if any(lo <= o <= hi for lo, hi in wide) else 1


CSI_RE = re.compile(r"\x1b\[([0-9;?]*)([ -/]*)([@-~])")


class Screen:
    """What the user would actually be looking at.

    Replays a captured byte stream - cursor moves, erases, text - into a grid.
    Necessary for any app rendering with Render_Mode.Cell_Diff, where the
    stream carries only the cells that changed and never contains a whole
    frame after the first.
    """

    def __init__(self, cols=80, rows=24):
        self.cols, self.rows = cols, rows
        self.grid = [[" "] * cols for _ in range(rows)]
        self.x = self.y = 0

    def _put(self, ch):
        w = _cell_width(ch)
        if 0 <= self.y < self.rows and 0 <= self.x < self.cols:
            self.grid[self.y][self.x] = ch
            if w == 2 and self.x + 1 < self.cols:
                self.grid[self.y][self.x + 1] = ""
        self.x += w

    def _erase(self, x0, x1, y0, y1):
        for y in range(max(y0, 0), min(y1, self.rows)):
            for x in range(max(x0, 0), min(x1, self.cols)):
                self.grid[y][x] = " "

    def feed(self, data: bytes):
        text = data.decode("utf-8", errors="replace")
        i = 0
        while i < len(text):
            ch = text[i]

            if ch == "\x1b":
                m = CSI_RE.match(text, i)
                if not m:
                    # OSC/DCS and friends: skip to the terminator.
                    end = text.find("\x07", i)
                    esc = text.find("\x1b\\", i)
                    if esc != -1 and (end == -1 or esc < end):
                        i = esc + 2
                    elif end != -1:
                        i = end + 1
                    else:
                        i += 2
                    continue

                params, final = m.group(1), m.group(3)
                i = m.end()
                if params.startswith("?"):
                    continue  # private modes do not touch the grid

                nums = [int(p) if p.isdigit() else 0 for p in params.split(";")] if params else []
                n = nums[0] if nums else 0

                if final in "Hf":
                    self.y = (nums[0] - 1) if len(nums) > 0 and nums[0] else 0
                    self.x = (nums[1] - 1) if len(nums) > 1 and nums[1] else 0
                elif final == "A":
                    self.y -= max(n, 1)
                elif final == "B":
                    self.y += max(n, 1)
                elif final == "C":
                    self.x += max(n, 1)
                elif final == "D":
                    self.x -= max(n, 1)
                elif final == "G":
                    self.x = max(n, 1) - 1
                elif final == "J":
                    if n == 0:
                        self._erase(self.x, self.cols, self.y, self.y + 1)
                        self._erase(0, self.cols, self.y + 1, self.rows)
                    elif n == 1:
                        self._erase(0, self.cols, 0, self.y)
                        self._erase(0, self.x + 1, self.y, self.y + 1)
                    else:
                        self._erase(0, self.cols, 0, self.rows)
                elif final == "K":
                    if n == 0:
                        self._erase(self.x, self.cols, self.y, self.y + 1)
                    elif n == 1:
                        self._erase(0, self.x + 1, self.y, self.y + 1)
                    else:
                        self._erase(0, self.cols, self.y, self.y + 1)
                continue

            i += 1
            if ch == "\n":
                self.y += 1
                self.x = 0
            elif ch == "\r":
                self.x = 0
            elif ch == "\t":
                self.x = ((self.x // 8) + 1) * 8
            elif ch >= " ":
                self._put(ch)

    def row(self, y: int) -> str:
        if not 0 <= y < self.rows:
            return ""
        return "".join(self.grid[y]).rstrip()

    def text(self) -> str:
        return "\n".join(self.row(y) for y in range(self.rows))


class Timeout(Exception):
    pass


class App:
    """A munin binary running on a pty."""

    def __init__(self, name, cols=80, rows=24, args=None):
        self.name = name
        self.cols, self.rows = cols, rows
        self.path = os.path.join(BIN_DIR, name)
        if not os.path.exists(self.path):
            raise FileNotFoundError(
                f"{self.path} not built - run `make examples` first"
            )

        self.master, slave = pty.openpty()
        self._set_winsize(cols, rows)

        self.proc = subprocess.Popen(
            [self.path] + (args or []),
            stdin=slave,
            stdout=slave,
            stderr=slave,
            close_fds=True,
            start_new_session=True,
        )
        os.close(slave)

        self._buf = bytearray()
        self._lock = threading.Lock()
        self._eof = False
        self._reader = threading.Thread(target=self._read_loop, daemon=True)
        self._reader.start()

    # -- lifecycle ----------------------------------------------------

    def _set_winsize(self, cols, rows):
        fcntl.ioctl(
            self.master, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0)
        )

    def _read_loop(self):
        while True:
            try:
                chunk = os.read(self.master, 65536)
            except OSError as e:
                # The pty reports EIO once the child closes its end.
                if e.errno in (errno.EIO, errno.EBADF):
                    chunk = b""
                else:
                    raise
            if not chunk:
                with self._lock:
                    self._eof = True
                return
            with self._lock:
                self._buf.extend(chunk)

    def output(self) -> bytes:
        with self._lock:
            return bytes(self._buf)

    def text(self) -> str:
        return strip_ansi(self.output())

    def screen(self) -> Screen:
        """Replay everything written so far into a grid.

        Use this instead of text() whenever what matters is the final display
        rather than the bytes - always, for a Cell_Diff app."""
        s = Screen(self.cols, self.rows)
        s.feed(self.output())
        return s

    def send(self, data):
        if isinstance(data, str):
            data = data.encode("utf-8")
        os.write(self.master, data)

    def resize(self, cols, rows):
        """Resize the window and notify the app, as a terminal emulator would."""
        self._set_winsize(cols, rows)
        self.signal(signal.SIGWINCH)

    def signal(self, sig):
        self.proc.send_signal(sig)

    # -- waiting ------------------------------------------------------

    def wait_for(self, needle, timeout=3.0, visible=True):
        """Block until `needle` shows up in the output. Returns the output."""
        deadline = time.monotonic() + timeout
        want = needle if isinstance(needle, str) else needle.decode()
        while time.monotonic() < deadline:
            haystack = self.text() if visible else self.output().decode(
                "utf-8", errors="replace"
            )
            if want in haystack:
                return haystack
            if self.proc.poll() is not None and self._eof:
                break
            time.sleep(0.02)
        raise Timeout(
            f"{self.name}: never saw {want!r}\n--- output so far ---\n{self.text()}"
        )

    def wait_for_re(self, pattern, timeout=3.0):
        """Like wait_for, but matches a regex against the visible text."""
        rx = re.compile(pattern)
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            visible = self.text()
            m = rx.search(visible)
            if m:
                return m
            if self.proc.poll() is not None and self._eof:
                break
            time.sleep(0.02)
        raise Timeout(
            f"{self.name}: never matched {pattern!r}\n"
            f"--- output so far ---\n{self.text()}"
        )

    def wait_quiet(self, idle=0.25, timeout=3.0):
        """Wait until the app stops writing for `idle` seconds."""
        deadline = time.monotonic() + timeout
        last_len = -1
        last_change = time.monotonic()
        while time.monotonic() < deadline:
            cur = len(self.output())
            if cur != last_len:
                last_len, last_change = cur, time.monotonic()
            elif time.monotonic() - last_change >= idle:
                return
            time.sleep(0.02)

    def wait_exit(self, timeout=3.0):
        try:
            return self.proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            raise Timeout(f"{self.name}: did not exit within {timeout}s")

    def quit(self, key="q", timeout=3.0):
        """Send the quit key and return the exit status."""
        self.send(key)
        return self.wait_exit(timeout)

    def kill(self):
        if self.proc.poll() is None:
            try:
                os.killpg(os.getpgid(self.proc.pid), signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
            try:
                self.proc.wait(timeout=1)
            except subprocess.TimeoutExpired:
                pass

    def close(self):
        self.kill()
        try:
            os.close(self.master)
        except OSError:
            pass

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()
        return False


# ============================================================
# Tiny test registry (keeps the runner dependency-free)
# ============================================================

_TESTS = []


def e2e(fn):
    _TESTS.append(fn)
    return fn


def run_all(pattern=None):
    selected = [f for f in _TESTS if not pattern or pattern in f.__name__]
    failures = []

    print(f"Running {len(selected)} e2e tests against {BIN_DIR}\n")
    for fn in selected:
        name = fn.__name__
        started = time.monotonic()
        try:
            fn()
        except Exception as e:  # noqa: BLE001 - report everything
            failures.append((name, e))
            print(f"  FAIL  {name}  ({time.monotonic() - started:.2f}s)")
            for line in str(e).splitlines():
                print(f"          {line}")
        else:
            print(f"  ok    {name}  ({time.monotonic() - started:.2f}s)")

    print()
    if failures:
        print(f"{len(failures)} of {len(selected)} e2e tests FAILED")
        return 1
    print(f"All {len(selected)} e2e tests passed")
    return 0


def main():
    pattern = sys.argv[1] if len(sys.argv) > 1 else None
    sys.exit(run_all(pattern))
