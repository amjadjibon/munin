package munin

import "core:fmt"
import "core:sync"
import "core:testing"

// ============================================================
// TERMINAL TESTS - Window size, raw mode, thread safety
// ============================================================

// ============================================================
// WINDOW SIZE TESTS
// ============================================================

@(test)
test_get_window_size :: proc(t: ^testing.T) {
	width, height, ok := get_window_size()

	if ok {
		// If we successfully got window size, verify it's reasonable
		testing.expect(t, width > 0, "Window width should be positive")
		testing.expect(t, height > 0, "Window height should be positive")
		testing.expect(t, width < 10000, "Window width should be reasonable")
		testing.expect(t, height < 10000, "Window height should be reasonable")
	} else {
		// In a test environment without a terminal, this might fail
		// That's okay, we just verify the function returns properly
		fmt.println(
			"get_window_size returned false (no terminal available) - expected in headless/CI environments",
		)
		return
	}
}

@(test)
test_get_window_size_consistency :: proc(t: ^testing.T) {
	// Call twice, should get same result (unless window is resized between calls)
	width1, height1, ok1 := get_window_size()
	width2, height2, ok2 := get_window_size()

	testing.expect_value(t, ok1, ok2)
	if ok1 && ok2 {
		// In test environment these should be identical
		testing.expect_value(t, width1, width2)
		testing.expect_value(t, height1, height2)
	}
}

// ============================================================
// TERMINAL STATE TESTS
// ============================================================

@(test)
test_terminal_state_struct :: proc(t: ^testing.T) {
	// Test that Terminal_State is properly defined
	state: Terminal_State

	when ODIN_OS == .Windows {
		// Windows version should have DWORD fields
		_ = state.old_mode
		_ = state.old_out_mode
	} else {
		// Unix version should have termios
		_ = state.old_termios
	}
}

// ============================================================
// PLATFORM-SPECIFIC TESTS
// ============================================================

@(test)
test_platform_detection :: proc(t: ^testing.T) {
	// Verify ODIN_OS is set to something
	when ODIN_OS == .Windows {
		fmt.println("Running on Windows")
	} else when ODIN_OS == .Linux {
		fmt.println("Running on Linux")
	} else when ODIN_OS == .Darwin {
		fmt.println("Running on macOS")
	} else {
		fmt.println("Running on unknown OS")
	}

	// Just verify the test runs without crashing
	testing.expect(t, true, "Platform detection should work")
}

// ============================================================
// IOCTL CONSTANT TESTS
// ============================================================

@(test)
test_tiocgwinsz_constant :: proc(t: ^testing.T) {
	when ODIN_OS != .Windows {
		// Verify TIOCGWINSZ is defined
		when ODIN_OS == .Linux {
			testing.expect_value(t, TIOCGWINSZ, 0x5413)
		} else {
			testing.expect_value(t, TIOCGWINSZ, 0x40087468)
		}
	}
}

@(test)
test_sigwinch_constant :: proc(t: ^testing.T) {
	when ODIN_OS != .Windows {
		// Verify SIGWINCH is defined
		testing.expect_value(t, SIGWINCH, 28)
	}
}

// ============================================================
// EDGE CASES AND BOUNDARY TESTS
// ============================================================


@(test)
test_check_window_resized_windows :: proc(t: ^testing.T) {
	when ODIN_OS == .Windows {
		// On Windows, this should always return false
		resized := check_window_resized()
		testing.expect(t, !resized, "Windows should not support resize detection")
	}
}

// ============================================================
// SIGNAL DISPOSITION (REGRESSION)
// ============================================================

when ODIN_OS != .Windows {
	@(test)
	test_restore_mode_hands_signals_back_to_default :: proc(t: ^testing.T) {
		// munin's fatal handler exits through _exit(). Leaving it installed
		// after run() has returned means a later signal skips whatever
		// cleanup the application still had to do.
		//
		// Save and restore the process-wide dispositions around the check so
		// this test cannot disturb the test runner.
		saved_int := signal(SIGINT, SIG_DFL)
		saved_term := signal(SIGTERM, SIG_DFL)
		saved_hup := signal(SIGHUP, SIG_DFL)
		saved_winch := signal(SIGWINCH, SIG_DFL)
		defer {
			signal(SIGINT, saved_int)
			signal(SIGTERM, saved_term)
			signal(SIGHUP, saved_hup)
			signal(SIGWINCH, saved_winch)
		}

		setup_resize_handler()

		// Installed while the program is running.
		previous := signal(SIGTERM, sigfatal_handler)
		testing.expect(t, previous == sigfatal_handler, "run() should install a SIGTERM handler")

		state: Terminal_State
		restore_mode(state)

		testing.expect(
			t,
			signal(SIGINT, SIG_DFL) == SIG_DFL,
			"SIGINT should be back to the default disposition",
		)
		testing.expect(
			t,
			signal(SIGTERM, SIG_DFL) == SIG_DFL,
			"SIGTERM should be back to the default disposition",
		)
		testing.expect(
			t,
			signal(SIGHUP, SIG_DFL) == SIG_DFL,
			"SIGHUP should be back to the default disposition",
		)
		testing.expect(
			t,
			signal(SIGWINCH, SIG_DFL) == SIG_DFL,
			"SIGWINCH should be back to the default disposition",
		)
	}
}
