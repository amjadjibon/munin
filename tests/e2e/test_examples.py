#!/usr/bin/env python3
"""End-to-end tests: real binaries, real pty, real byte streams.

Run with `make e2e` (builds the examples first) or directly:

    python3 tests/e2e/test_examples.py [name-filter]
"""

import re
import signal
import time

from harness import App, e2e, main

# ============================================================
# TERMINAL SETUP AND TEARDOWN
# ============================================================


@e2e
def test_fullscreen_enters_alt_screen_and_leaves_it():
    with App("counter") as app:
        app.wait_for("Counter: 0")
        out = app.output()

        assert b"\x1b[?1049h" in out, "should switch to the alternate screen"
        assert b"\x1b[?25l" in out, "should hide the cursor"
        assert b"\x1b[?1049l" not in out, "must not leave the alt screen while running"

        assert app.quit() == 0, "should exit cleanly on q"

        out = app.output()
        enter = out.index(b"\x1b[?1049h")
        leave = out.rindex(b"\x1b[?1049l")
        assert leave > enter, "alt screen must be left only at exit"


@e2e
def test_terminal_state_restored_on_exit():
    with App("counter") as app:
        app.wait_for("Counter: 0")
        assert app.quit() == 0

        out = app.output()
        assert b"\x1b[?25h" in out, "should show the cursor again"
        assert b"\x1b[?7h" in out, "should re-enable line wrapping"


@e2e
def test_inline_mode_never_uses_alt_screen():
    with App("inline") as app:
        app.wait_for("INLINE MODE")
        assert b"\x1b[?1049h" not in app.output(), "inline mode must not switch screens"

        assert app.quit() == 0


@e2e
def test_inline_mode_redraws_in_place():
    with App("inline") as app:
        app.wait_for("Counter: 0")
        before = len(app.output())

        app.send(" ")
        app.wait_for("Counter: 1")

        delta = app.output()[before:]
        # Redraw walks the cursor back up over the previous frame.
        assert b"\x1b[" in delta and b"A" in delta, "should move the cursor up to redraw"
        assert b"\x1b[J" in delta, "should clear from the cursor down"

        assert app.quit() == 0


# ============================================================
# INPUT HANDLING
# ============================================================


@e2e
def test_keys_update_the_model():
    with App("counter") as app:
        app.wait_for("Counter: 0")

        app.send("   ")  # three increments
        app.wait_for("Counter: 3")

        app.send("d")
        app.wait_for("Counter: 2")

        assert app.quit() == 0


@e2e
def test_burst_of_keystrokes_is_not_dropped():
    # Regression: input used to drain one event per frame, so a paste of N
    # characters took N frames (N/60 seconds) and backed up the input buffer.
    # The timing bound is what makes this a regression test rather than a
    # liveness check: 26 characters took ~0.45s one-per-frame, and land in
    # a single frame now.
    text = "zqwertyuiopasdfghjklzxcvbn"
    with App("forms") as app:
        app.wait_for("Enter username")

        started = time.monotonic()
        app.send(text)  # single write, all at once
        app.wait_for(text, timeout=2.0)
        elapsed = time.monotonic() - started

        assert elapsed < 0.25, f"{len(text)} characters took {elapsed:.2f}s to arrive"

        assert app.quit(key="\x1b") == 0  # Escape quits the forms example


@e2e
def test_unknown_escape_sequence_is_not_typed_into_the_field():
    # Regression: an unrecognised CSI consumed only the ESC, so "[15~" was
    # delivered to the application as four literal keystrokes.
    with App("forms") as app:
        app.wait_for("Enter username")

        app.send("\x1b[15~")  # F5
        app.send("\x1b[200~")  # bracketed paste start
        app.send("ok")
        app.wait_for("ok")

        visible = app.text()
        assert "[15~" not in visible, "F5 leaked into the input field"
        assert "[200~" not in visible, "paste marker leaked into the input field"

        assert app.quit(key="\x1b") == 0


@e2e
def test_utf8_input_is_decoded():
    with App("forms") as app:
        app.wait_for("Enter username")

        app.send("héllo")
        app.wait_for("héllo")

        assert app.quit(key="\x1b") == 0


@e2e
def test_ctrl_c_is_reported_as_a_control_key():
    with App("forms") as app:
        app.wait_for("Enter username")
        app.send("\x03")
        assert app.wait_exit() == 0, "Ctrl+C should quit the forms example"


@e2e
def test_garbage_input_does_not_break_the_app():
    junk = (
        b"\x1b\x1b\x1b"  # bare escapes
        b"\x1b[999999999999999999999m"  # absurd CSI parameter
        b"\x1b]0;" + b"A" * 200  # unterminated OSC
        + b"\xff\xfe\xfd"  # invalid UTF-8
        b"\x1b[<99999999999;1;1M"  # out-of-range mouse coordinates
        b"\x1b[" + b"9" * 300  # very long unterminated CSI
    )
    with App("counter") as app:
        app.wait_for("Counter: 0")

        app.send(junk)
        app.wait_quiet()

        # Still alive and still processing real input.
        app.send(" ")
        app.wait_for("Counter: 1", timeout=3.0)

        assert app.quit() == 0


# ============================================================
# MOUSE
# ============================================================


@e2e
def test_mouse_tracking_is_enabled_and_disabled():
    with App("mouse") as app:
        app.wait_for("Mouse Position")
        assert b"\x1b[?1006h" in app.output(), "should enable SGR mouse reporting"

        assert app.quit() == 0
        assert b"\x1b[?1006l" in app.output(), "should disable mouse reporting on exit"


@e2e
def test_mouse_click_coordinates_are_reported():
    with App("mouse") as app:
        app.wait_for("Mouse Position")

        # SGR press at column 10, row 20 (1-based on the wire)
        app.send("\x1b[<0;10;20M")
        app.wait_for_re(r"X:\s*0*9,\s*Y:\s*0*19")

        assert app.quit() == 0


@e2e
def test_malformed_mouse_sequence_is_rejected():
    # Regression: non-digit bytes were fed through `b - '0'`, producing
    # garbage coordinates that an application would index arrays with.
    with App("mouse") as app:
        app.wait_for("Mouse Position")

        app.send("\x1b[<AAAA;BBBB;CCCCM")
        app.send("\x1b[<0;99999999999999;1M")
        app.wait_quiet()

        # No coordinate on screen may exceed the terminal size. Unvalidated
        # digits used to yield values like 7766279631452241918.
        for match in re.finditer(r"[XY]:\s*(\d+)", app.text()):
            assert int(match.group(1)) < 10000, f"absurd coordinate {match.group(1)}"

        # A valid event afterwards must still be parsed correctly.
        app.send("\x1b[<0;5;7M")
        app.wait_for_re(r"X:\s*0*4,\s*Y:\s*0*6")

        assert app.quit() == 0


# ============================================================
# SIGNALS AND RESIZE
# ============================================================


@e2e
def test_sigterm_restores_the_terminal():
    # Regression: with ISIG cleared and cleanup only in a defer, a killed
    # process left the terminal in raw mode with the cursor hidden.
    with App("counter") as app:
        app.wait_for("Counter: 0")

        app.signal(signal.SIGTERM)
        rc = app.wait_exit()
        assert rc == 128 + signal.SIGTERM or rc == -signal.SIGTERM, f"exit status {rc}"

        tail = app.output()
        assert b"\x1b[?25h" in tail, "should show the cursor before dying"
        assert b"\x1b[?1049l" in tail, "should leave the alternate screen"


@e2e
def test_sigint_restores_the_terminal():
    with App("counter") as app:
        app.wait_for("Counter: 0")

        app.signal(signal.SIGINT)
        app.wait_exit()

        assert b"\x1b[?25h" in app.output(), "should show the cursor before dying"


@e2e
def test_sigterm_disables_mouse_reporting():
    with App("mouse") as app:
        app.wait_for("Mouse Position")

        app.signal(signal.SIGTERM)
        app.wait_exit()

        assert b"\x1b[?1006l" in app.output(), "mouse reporting must be turned off"


@e2e
def test_resize_is_handled():
    with App("counter", cols=100, rows=30) as app:
        app.wait_for("Counter: 0")

        app.resize(60, 20)
        app.wait_quiet()

        app.send(" ")
        app.wait_for("Counter: 1")

        assert app.quit() == 0


@e2e
def test_narrow_terminal_does_not_crash():
    with App("counter", cols=10, rows=5) as app:
        app.wait_for("Counter")
        app.send(" ")
        app.wait_quiet()
        assert app.quit() == 0


@e2e
def test_identical_frames_are_not_retransmitted():
    # Every redraw retransmits the whole view, so an event that does not
    # change anything used to cost a full frame of terminal traffic.
    with App("mouse", cols=80, rows=24) as app:
        app.wait_for("Mouse Position")

        # One event that does change the view: costs a frame.
        app.send("\x1b[<35;40;12M")
        app.wait_quiet(idle=0.2)

        base = len(app.output())
        for _ in range(20):
            app.send("\x1b[<35;40;12M")  # same position, identical view
            time.sleep(0.02)
        app.wait_quiet(idle=0.3)
        repeated = len(app.output()) - base

        assert repeated == 0, f"{repeated} bytes written for 20 no-op redraws"

        assert app.quit() == 0


if __name__ == "__main__":
    main()
