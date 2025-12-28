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
