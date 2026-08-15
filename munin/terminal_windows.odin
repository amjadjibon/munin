package munin

import win32 "core:sys/windows"

when ODIN_OS == .Windows {
	// Not declared by core:sys/windows. Value from wincon.h.
	@(private)
	ENABLE_EXTENDED_FLAGS :: win32.DWORD(0x0080)

	Terminal_State :: struct {
		old_mode:     win32.DWORD,
		old_out_mode: win32.DWORD,
	}

	// Cached window size. Windows has no SIGWINCH, so a resize is detected by
	// comparing the console size against the last one we saw - which is also
	// what lets get_window_size() avoid a console call per frame.
	@(private)
	cached_width: int = 0
	@(private)
	cached_height: int = 0
	@(private)
	size_valid: bool = false

	set_raw_mode :: proc() -> (Terminal_State, bool) {
		state: Terminal_State

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
		new_mode |= win32.ENABLE_MOUSE_INPUT | ENABLE_EXTENDED_FLAGS
		if !win32.SetConsoleMode(stdin, new_mode) {
			return state, false
		}

		new_out_mode := state.old_out_mode | win32.ENABLE_VIRTUAL_TERMINAL_PROCESSING
		win32.SetConsoleMode(stdout, new_out_mode)

		return state, true
	}

	restore_mode :: proc(state: Terminal_State) {
		stdin := win32.GetStdHandle(win32.STD_INPUT_HANDLE)
		stdout := win32.GetStdHandle(win32.STD_OUTPUT_HANDLE)
		win32.SetConsoleMode(stdin, state.old_mode)
		win32.SetConsoleMode(stdout, state.old_out_mode)
		size_valid = false
	}

	// Ask the console for its current size, bypassing the cache.
	@(private)
	query_window_size :: proc() -> (width, height: int, ok: bool) {
		stdout := win32.GetStdHandle(win32.STD_OUTPUT_HANDLE)
		info: win32.CONSOLE_SCREEN_BUFFER_INFO

		if !win32.GetConsoleScreenBufferInfo(stdout, &info) {
			return 0, 0, false
		}

		width = int(info.srWindow.Right - info.srWindow.Left + 1)
		height = int(info.srWindow.Bottom - info.srWindow.Top + 1)
		return width, height, true
	}

	get_window_size :: proc() -> (width, height: int, ok: bool) {
		if size_valid {
			return cached_width, cached_height, true
		}

		w, h, got := query_window_size()
		if !got {
			return 0, 0, false
		}

		cached_width, cached_height, size_valid = w, h, true
		return w, h, true
	}

	// Polled once per frame by the run loop. Without this a resized console
	// left every layout stuck at the size the program started with.
	check_window_resized :: proc() -> bool {
		w, h, ok := query_window_size()
		if !ok {
			return false
		}

		if !size_valid {
			cached_width, cached_height, size_valid = w, h, true
			return false
		}

		if w != cached_width || h != cached_height {
			cached_width, cached_height = w, h
			return true
		}
		return false
	}

	setup_resize_handler :: proc() {
		// Nothing to install: resizes are polled in check_window_resized.
		// Prime the cache so the first poll is not reported as a resize.
		size_valid = false
		get_window_size()
	}

	// No-ops on Windows: there is no signal handler needing to know what to
	// undo. Kept so run() can call them unconditionally.
	@(private)
	set_cleanup_state :: proc(mouse: bool, altscreen: bool) {
	}

	@(private)
	set_cleanup_altscreen :: proc(on: bool) {
	}
}
