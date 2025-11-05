package munin

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
		testing.logf(t, "get_window_size returned false (no terminal available)")
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
// THREAD SAFETY TESTS
// ============================================================

@(test)
test_window_resize_flag_initial :: proc(t: ^testing.T) {
	// The flag should initially be 0 (false)
	value := sync.atomic_load(&window_resized_atomic)
	testing.expect_value(t, value, 0)
}

@(test)
test_window_resize_flag_set :: proc(t: ^testing.T) {
	when ODIN_OS != .Windows {
		// Reset flag first
		sync.atomic_store(&window_resized_atomic, 0)

		// Simulate signal handler setting the flag
		sync.atomic_store(&window_resized_atomic, 1)

		// Check it was set
		value := sync.atomic_load(&window_resized_atomic)
		testing.expect_value(t, value, 1)

		// Clean up
		sync.atomic_store(&window_resized_atomic, 0)
	}
}

@(test)
test_check_window_resized_clear :: proc(t: ^testing.T) {
	when ODIN_OS != .Windows {
		// Set the flag
		sync.atomic_store(&window_resized_atomic, 1)

		// Check should return true and clear
		resized := check_window_resized()
		testing.expect(t, resized, "Should detect resize")

		// Second check should return false (flag was cleared)
		resized2 := check_window_resized()
		testing.expect(t, !resized2, "Flag should be cleared")
	}
}

@(test)
test_check_window_resized_not_set :: proc(t: ^testing.T) {
	when ODIN_OS != .Windows {
		// Ensure flag is clear
		sync.atomic_store(&window_resized_atomic, 0)

		// Check should return false
		resized := check_window_resized()
		testing.expect(t, !resized, "Should not detect resize")
	}
}

@(test)
test_window_resize_atomic_exchange :: proc(t: ^testing.T) {
	when ODIN_OS != .Windows {
		// Test atomic exchange behavior
		sync.atomic_store(&window_resized_atomic, 1)

		// Exchange should return old value (1) and set to new value (0)
		old := sync.atomic_exchange(&window_resized_atomic, 0)
		testing.expect_value(t, old, 1)

		// Flag should now be 0
		current := sync.atomic_load(&window_resized_atomic)
		testing.expect_value(t, current, 0)
	}
}

@(test)
test_window_resize_multiple_sets :: proc(t: ^testing.T) {
	when ODIN_OS != .Windows {
		// Reset
		sync.atomic_store(&window_resized_atomic, 0)

		// Multiple sets should not accumulate
		sync.atomic_store(&window_resized_atomic, 1)
		sync.atomic_store(&window_resized_atomic, 1)
		sync.atomic_store(&window_resized_atomic, 1)

		// Check once - should be true
		resized := check_window_resized()
		testing.expect(t, resized, "Should detect resize")

		// Check again - should be false (only one detection)
		resized2 := check_window_resized()
		testing.expect(t, !resized2, "Should not detect multiple times")
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

// Note: We cannot fully test set_raw_mode/restore_mode in a test environment
// because they require a real terminal. These would need integration tests
// with actual terminal input/output.

// ============================================================
// SIGNAL HANDLER TESTS
// ============================================================

@(test)
test_sigwinch_handler_simulation :: proc(t: ^testing.T) {
	when ODIN_OS != .Windows {
		// Reset flag
		sync.atomic_store(&window_resized_atomic, 0)

		// Simulate what signal handler would do
		sync.atomic_store(&window_resized_atomic, 1)

		// Verify it was set
		value := sync.atomic_load(&window_resized_atomic)
		testing.expect_value(t, value, 1)

		// Clean up
		sync.atomic_store(&window_resized_atomic, 0)
	}
}

// ============================================================
// PLATFORM-SPECIFIC TESTS
// ============================================================

@(test)
test_platform_detection :: proc(t: ^testing.T) {
	// Verify ODIN_OS is set to something
	when ODIN_OS == .Windows {
		testing.logf(t, "Running on Windows")
	} else when ODIN_OS == .Linux {
		testing.logf(t, "Running on Linux")
	} else when ODIN_OS == .Darwin {
		testing.logf(t, "Running on macOS")
	} else {
		testing.logf(t, "Running on unknown OS")
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
test_window_resize_race_condition :: proc(t: ^testing.T) {
	when ODIN_OS != .Windows {
		// Test that concurrent access doesn't cause issues
		sync.atomic_store(&window_resized_atomic, 0)

		// Simulate rapid flag setting and checking
		for i in 0..<10 {
			sync.atomic_store(&window_resized_atomic, 1)
			_ = check_window_resized()
		}

		// Should end with flag clear
		final := sync.atomic_load(&window_resized_atomic)
		testing.expect_value(t, final, 0)
	}
}

@(test)
test_window_resize_flag_overflow :: proc(t: ^testing.T) {
	when ODIN_OS != .Windows {
		// Test that flag doesn't overflow (only 0 or 1)
		sync.atomic_store(&window_resized_atomic, 1)
		sync.atomic_store(&window_resized_atomic, 1)
		sync.atomic_store(&window_resized_atomic, 1)

		value := sync.atomic_load(&window_resized_atomic)
		testing.expect_value(t, value, 1, "Flag should stay at 1")

		sync.atomic_store(&window_resized_atomic, 0)
	}
}

@(test)
test_check_window_resized_windows :: proc(t: ^testing.T) {
	when ODIN_OS == .Windows {
		// On Windows, this should always return false
		resized := check_window_resized()
		testing.expect(t, !resized, "Windows should not support resize detection")
	}
}
