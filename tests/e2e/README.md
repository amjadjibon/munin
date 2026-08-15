# End-to-end tests

These tests run the **built example binaries** on a real pseudo-terminal, send
them real keystrokes, escape sequences and signals, and assert on the bytes
they write back.

They cover the parts of a TUI framework that unit tests structurally cannot:

- terminal setup and teardown (alternate screen, cursor visibility, line wrap)
- restoring the terminal when the process is killed
- parsing real input byte streams (UTF-8, CSI, SS3, SGR mouse, garbage)
- input throughput — a pasted burst arriving in one frame, not one key per frame
- window resize handling

## Running

```bash
make e2e                 # builds the examples, then runs the suite
make e2e E2E=mouse       # only tests whose name contains "mouse"

python3 tests/e2e/test_examples.py          # if the binaries are already built
python3 tests/e2e/test_examples.py signal   # filter
```

`MUNIN_BIN=/path/to/bin` points the suite at a different build — useful for
bisecting a regression.

## Requirements

Python 3 (standard library only — no pytest, no pexpect) and a POSIX pty.
Not supported on Windows.

## Layout

- `harness.py` — pty process driver (`App`) plus the tiny test registry
- `test_examples.py` — the scenarios

## Writing a test

```python
@e2e
def test_something():
    with App("counter", cols=80, rows=24) as app:
        app.wait_for("Counter: 0")   # visible text, ANSI stripped
        app.send(" ")
        app.wait_for("Counter: 1")
        assert app.quit() == 0       # sends "q", returns the exit status
```

`App` also offers `wait_for_re`, `wait_quiet`, `output()` (raw bytes, escape
sequences included), `text()` (visible text), `resize(cols, rows)`, `signal()`
and `wait_exit()`.

Keep assertions about *behaviour* (what the user sees, what the terminal is
left in), not about exact frame bytes — examples change their wording.
