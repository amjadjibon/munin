package munin

import "core:c"
import "core:sync"
import "core:sys/posix"
import win32 "core:sys/windows"

// Unix ioctl definitions for window size
when ODIN_OS != .Windows {
	foreign import libc "system:c"

	winsize :: struct {
		ws_row:    c.ushort,
		ws_col:    c.ushort,
		ws_xpixel: c.ushort,
		ws_ypixel: c.ushort,
	}

	TIOCGWINSZ :: 0x5413 when ODIN_OS == .Linux else 0x40087468
	SIGWINCH :: 28

	@(default_calling_convention = "c")
	foreign libc {
		ioctl :: proc(fd: c.int, request: c.ulong, #c_vararg args: ..any) -> c.int ---
		signal :: proc(sig: c.int, handler: proc "c" (c.int)) -> proc "c" (c.int) ---
	}
}

// Global flag for window resize detection (using atomic for thread safety)
// 0 = false, 1 = true
@(private)
window_resized_atomic: sync.Atomic_Int = {}

// Cached window size (to avoid repeated ioctl/syscalls)
@(private)
cached_window_width: int = 0
@(private)
cached_window_height: int = 0
@(private)
cache_valid: bool = false

// Signal handler for SIGWINCH (window resize)
when ODIN_OS != .Windows {
	@(private)
	sigwinch_handler :: proc "c" (sig: c.int) {
		// Atomically set the flag to 1 (true)
		sync.atomic_store(&window_resized_atomic, 1)
	}
}

// ============================================================
// TERMINAL STATE
// ============================================================

when ODIN_OS == .Windows {
	Terminal_State :: struct {
		old_mode:     win32.DWORD,
		old_out_mode: win32.DWORD,
	}
} else {
	Terminal_State :: struct {
		old_termios: posix.termios,
	}
}

// ============================================================
// RAW MODE
// ============================================================

set_raw_mode :: proc() -> (Terminal_State, bool) {
	state: Terminal_State

	when ODIN_OS == .Windows {
		stdin := win32.GetStdHandle(win32.STD_INPUT_HANDLE)
		stdout := win32.GetStdHandle(win32.STD_OUTPUT_HANDLE)

		if !win32.GetConsoleMode(stdin, &state.old_mode) {
			return state, false
		}
		if !win32.GetConsoleMode(stdout, &state.old_out_mode) {
			return state, false
		}

		// Enable mouse input in addition to raw mode
		new_mode := state.old_mode & ~(win32.ENABLE_LINE_INPUT | win32.ENABLE_ECHO_INPUT)
		new_mode |= win32.ENABLE_MOUSE_INPUT | win32.ENABLE_EXTENDED_FLAGS
		if !win32.SetConsoleMode(stdin, new_mode) {
			return state, false
		}

		new_out_mode := state.old_out_mode | win32.ENABLE_VIRTUAL_TERMINAL_PROCESSING
		win32.SetConsoleMode(stdout, new_out_mode)

		return state, true
	} else {
		// Get current terminal attributes
		if posix.tcgetattr(posix.STDIN_FILENO, &state.old_termios) == .FAIL {
			return state, false
		}

		// Create new termios with raw mode settings
		raw := state.old_termios

		// Disable canonical mode, echo, and signals
		raw.c_lflag &= ~posix.CLocal_Flags{.ICANON, .ECHO, .ISIG, .IEXTEN}
		// Disable input processing
		raw.c_iflag &= ~posix.CInput_Flags{.BRKINT, .IGNPAR}
		// Set non-blocking read with minimum characters = 0, timeout = 0
		raw.c_cc[posix.Control_Char.VMIN] = 0
		raw.c_cc[posix.Control_Char.VTIME] = 0

		// Apply new settings immediately
		if posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &raw) == .FAIL {
			return state, false
		}

		return state, true
	}
}

restore_mode :: proc(state: Terminal_State) {
	when ODIN_OS == .Windows {
		stdin := win32.GetStdHandle(win32.STD_INPUT_HANDLE)
		stdout := win32.GetStdHandle(win32.STD_OUTPUT_HANDLE)
		win32.SetConsoleMode(stdin, state.old_mode)
		win32.SetConsoleMode(stdout, state.old_out_mode)
	} else {
		// Restore original terminal attributes
		t := state.old_termios
		posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &t)
	}
}

// ============================================================
// WINDOW SIZE
// ============================================================

// Get the terminal window size (columns, rows)
// This function caches the result and only queries the system on first call or after resize
get_window_size :: proc() -> (width, height: int, ok: bool) {
	// Return cached value if valid
	if cache_valid {
		return cached_window_width, cached_window_height, true
	}

	// Query system for window size
	when ODIN_OS == .Windows {
		stdout := win32.GetStdHandle(win32.STD_OUTPUT_HANDLE)
		info: win32.CONSOLE_SCREEN_BUFFER_INFO

		if !win32.GetConsoleScreenBufferInfo(stdout, &info) {
			return 0, 0, false
		}

		width = int(info.srWindow.Right - info.srWindow.Left + 1)
		height = int(info.srWindow.Bottom - info.srWindow.Top + 1)
	} else {
		// Use TIOCGWINSZ ioctl to get window size
		ws: winsize

		if ioctl(1, TIOCGWINSZ, &ws) == -1 {
			return 0, 0, false
		}

		width = int(ws.ws_col)
		height = int(ws.ws_row)
	}

	// Cache the result
	cached_window_width = width
	cached_window_height = height
	cache_valid = true

	return width, height, true
}

// Check if window was resized and clear the flag
// Also invalidates the window size cache if a resize was detected
check_window_resized :: proc() -> bool {
	when ODIN_OS != .Windows {
		// Atomically exchange the flag with 0 (false) and return previous value
		// This is thread-safe: if signal handler sets it to 1, we'll detect it exactly once
		previous := sync.atomic_exchange(&window_resized_atomic, 0)
		was_resized := previous != 0

		// Invalidate cache on resize
		if was_resized {
			cache_valid = false
		}

		return was_resized
	}
	return false
}

// Setup window resize detection
setup_resize_handler :: proc() {
	when ODIN_OS != .Windows {
		signal(SIGWINCH, sigwinch_handler)
	}
}
