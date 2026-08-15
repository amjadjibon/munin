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


class Timeout(Exception):
    pass


class App:
    """A munin binary running on a pty."""

    def __init__(self, name, cols=80, rows=24, args=None):
        self.name = name
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
