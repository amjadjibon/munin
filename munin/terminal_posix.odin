package munin

import "base:intrinsics"
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
	SIGINT :: 2
	SIGTERM :: 15
	SIGHUP :: 1

	// The default signal disposition: a null handler pointer.
	@(private)
	SIG_DFL: proc "c" (_: c.int) = nil

	@(default_calling_convention = "c")
	foreign libc {
		ioctl :: proc(fd: c.int, request: c.ulong, #c_vararg args: ..any) -> c.int ---
		signal :: proc(sig: c.int, handler: proc "c" (_: c.int)) -> proc "c" (_: c.int) ---
		write :: proc(fd: c.int, buf: rawptr, count: uint) -> int ---
		_exit :: proc(status: c.int) ---
	}

	// Global flag for window resize detection.
	// Written from a signal handler, so all access goes through atomics.
	@(private)
	window_resized: bool = false

	// Separate dirty flag for the window size cache, so consuming a resize
	// event via check_window_resized() does not leave a stale cached size.
	@(private)
	window_size_dirty: bool = true

	@(private)
	cached_width: int = 0
	@(private)
	cached_height: int = 0

	// Terminal state saved for emergency restore from a signal handler.
	// Only tcsetattr/write/_exit are used there, all of which are
	// async-signal-safe.
	@(private)
	saved_termios: posix.termios
	@(private)
	saved_termios_valid: bool = false
	@(private)
	cleanup_mouse: bool = false
	@(private)
	cleanup_altscreen: bool = false

	// Signal handler for SIGWINCH (window resize)
	@(private)
	sigwinch_handler :: proc "c" (sig: c.int) {
		intrinsics.atomic_store(&window_resized, true)
		intrinsics.atomic_store(&window_size_dirty, true)
	}

	// Signal handler for INT/TERM/HUP: put the terminal back the way we found
	// it before dying, otherwise the user is left in raw mode with a hidden
	// cursor and mouse reporting still on.
	@(private)
	sigfatal_handler :: proc "c" (sig: c.int) {
		emergency_restore()
		_exit(128 + sig)
	}

	// Restore terminal state using only async-signal-safe calls.
	@(private)
	emergency_restore :: proc "c" () {
		if intrinsics.atomic_load(&cleanup_mouse) {
			seq := "\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l"
			write(1, raw_data(seq), len(seq))
		}
		// Show cursor, re-enable line wrapping, reset attributes.
		reset_seq := "\x1b[?25h\x1b[?7h\x1b[0m"
		write(1, raw_data(reset_seq), len(reset_seq))

		if intrinsics.atomic_load(&cleanup_altscreen) {
			alt := "\x1b[?1049l"
			write(1, raw_data(alt), len(alt))
		}

		if intrinsics.atomic_load(&saved_termios_valid) {
			t := saved_termios
			posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &t)
		}
	}

	// Record which terminal features run() turned on, so the signal handler
	// knows what to undo.
	@(private)
	set_cleanup_state :: proc(mouse: bool, altscreen: bool) {
		intrinsics.atomic_store(&cleanup_mouse, mouse)
		intrinsics.atomic_store(&cleanup_altscreen, altscreen)
	}

	@(private)
	set_cleanup_altscreen :: proc(on: bool) {
		intrinsics.atomic_store(&cleanup_altscreen, on)
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
		// Disable input processing.
		// IXON must go too, otherwise Ctrl+S silently freezes all output.
		// ICRNL/INLCR would rewrite CR/LF under us; ISTRIP would destroy UTF-8.
		raw.c_iflag &= ~posix.CInput_Flags{.BRKINT, .IGNPAR, .IXON, .ICRNL, .INLCR, .ISTRIP}
		// Set non-blocking read with minimum characters = 0, timeout = 0
		raw.c_cc[posix.Control_Char.VMIN] = 0
		raw.c_cc[posix.Control_Char.VTIME] = 0

		// Apply new settings immediately
		if posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &raw) == .FAIL {
			return state, false
		}

		// Stash a copy for the fatal-signal handler.
		saved_termios = state.old_termios
		intrinsics.atomic_store(&saved_termios_valid, true)

		return state, true
	}

	restore_mode :: proc(state: Terminal_State) {
		// Restore original terminal attributes
		t := state.old_termios
		posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &t)
		intrinsics.atomic_store(&saved_termios_valid, false)
		set_cleanup_state(false, false)

		// Hand the signals back to the default disposition. Leaving our
		// handlers installed past the end of run() means a later SIGTERM
		// exits through _exit() and skips whatever cleanup the application
		// still had to do - freeing its model, flushing a log, reporting
		// leaks - none of which run() is responsible for any more.
		signal(SIGINT, SIG_DFL)
		signal(SIGTERM, SIG_DFL)
		signal(SIGHUP, SIG_DFL)
		signal(SIGWINCH, SIG_DFL)
	}

	// Query the terminal size.
	// Cached: the ioctl only runs on the first call and after a SIGWINCH,
	// since this sits on the per-frame render path.
	get_window_size :: proc() -> (width, height: int, ok: bool) {
		if !intrinsics.atomic_load(&window_size_dirty) && cached_width > 0 {
			return cached_width, cached_height, true
		}

		ws: winsize

		// stdout may be redirected to a file or pipe; fall back to stdin and
		// stderr before giving up.
		got := false
		for fd in ([3]c.int{1, 0, 2}) {
			if ioctl(fd, TIOCGWINSZ, &ws) != -1 && ws.ws_col > 0 {
				got = true
				break
			}
		}
		if !got {
			return 0, 0, false
		}

		cached_width = int(ws.ws_col)
		cached_height = int(ws.ws_row)
		intrinsics.atomic_store(&window_size_dirty, false)

		return cached_width, cached_height, true
	}

	check_window_resized :: proc() -> bool {
		if intrinsics.atomic_load(&window_resized) {
			intrinsics.atomic_store(&window_resized, false)
			return true
		}
		return false
	}

	setup_resize_handler :: proc() {
		signal(SIGWINCH, sigwinch_handler)
		signal(SIGINT, sigfatal_handler)
		signal(SIGTERM, sigfatal_handler)
		signal(SIGHUP, sigfatal_handler)
	}
}
