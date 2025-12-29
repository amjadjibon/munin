package munin

import win32 "core:sys/windows"

when ODIN_OS == .Windows {
	Terminal_State :: struct {
		old_mode:     win32.DWORD,
		old_out_mode: win32.DWORD,
	}

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
		new_mode |= win32.ENABLE_MOUSE_INPUT | win32.ENABLE_EXTENDED_FLAGS
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
	}

	get_window_size :: proc() -> (width, height: int, ok: bool) {
		stdout := win32.GetStdHandle(win32.STD_OUTPUT_HANDLE)
		info: win32.CONSOLE_SCREEN_BUFFER_INFO

		if !win32.GetConsoleScreenBufferInfo(stdout, &info) {
			return 0, 0, false
		}

		width = int(info.srWindow.Right - info.srWindow.Left + 1)
		height = int(info.srWindow.Bottom - info.srWindow.Top + 1)
		return width, height, true
	}

	check_window_resized :: proc() -> bool {
		return false
	}

	setup_resize_handler :: proc() {
		// Not implemented for Windows yet
	}
}
