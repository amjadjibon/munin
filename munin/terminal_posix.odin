package munin

import "core:c"
import "core:sys/posix"

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
		signal :: proc(sig: c.int, handler: proc "c" (_: c.int)) -> proc "c" (_: c.int) ---
	}

	// Global flag for window resize detection
	@(private)
	window_resized: bool = false

	// Signal handler for SIGWINCH (window resize)
	@(private)
	sigwinch_handler :: proc "c" (sig: c.int) {
		window_resized = true
	}

	Terminal_State :: struct {
		old_termios: posix.termios,
	}

	set_raw_mode :: proc() -> (Terminal_State, bool) {
		state: Terminal_State

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

	restore_mode :: proc(state: Terminal_State) {
		// Restore original terminal attributes
		t := state.old_termios
		posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &t)
	}

	get_window_size :: proc() -> (width, height: int, ok: bool) {
		// Use TIOCGWINSZ ioctl to get window size
		ws: winsize

		if ioctl(1, TIOCGWINSZ, &ws) == -1 {
			return 0, 0, false
		}

		width = int(ws.ws_col)
		height = int(ws.ws_row)
		return width, height, true
	}

	check_window_resized :: proc() -> bool {
		if window_resized {
			window_resized = false
			return true
		}
		return false
	}

	setup_resize_handler :: proc() {
		signal(SIGWINCH, sigwinch_handler)
	}
}
