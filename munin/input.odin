package munin

import "core:os"
import win32 "core:sys/windows"


// ============================================================
// INPUT
// ============================================================

Key :: enum {
	Unknown,
	Char,
	Up,
	Down,
	Left,
	Right,
	Enter,
	Escape,
	Backspace,
	Tab,
	PageUp,
	PageDown,
}

Key_Event :: struct {
	key:  Key,
	char: rune,
	shift: bool,
}

read_key :: proc() -> Maybe(Key_Event) {
	when ODIN_OS == .Windows {
		stdin := win32.GetStdHandle(win32.STD_INPUT_HANDLE)
		events_read: win32.DWORD
		event: win32.INPUT_RECORD

		if !win32.PeekConsoleInputW(stdin, &event, 1, &events_read) || events_read == 0 {
			return nil
		}

		if !win32.ReadConsoleInputW(stdin, &event, 1, &events_read) {
			return nil
		}

		if event.EventType == win32.KEY_EVENT && event.Event.KeyEvent.bKeyDown {
			vk := event.Event.KeyEvent.wVirtualKeyCode
			ch := event.Event.KeyEvent.uChar.UnicodeChar
			shift_key_state := event.Event.KeyEvent.dwControlKeyState & win32.SHIFT_PRESSED != 0

			result := Key_Event {
				key  = .Char,
				char = rune(ch),
				shift = shift_key_state,
			}

			switch vk {
			case win32.VK_UP:
				result.key = .Up
			case win32.VK_DOWN:
				result.key = .Down
			case win32.VK_LEFT:
				result.key = .Left
			case win32.VK_RIGHT:
				result.key = .Right
			case win32.VK_RETURN:
				result.key = .Enter
			case win32.VK_ESCAPE:
				result.key = .Escape
			case win32.VK_BACK:
				result.key = .Backspace
			case win32.VK_TAB:
				result.key = .Tab
			case win32.VK_PRIOR:
				result.key = .PageUp
			case win32.VK_NEXT:
				result.key = .PageDown
			}

			return result
		}
} else {
		buf: [6]byte  // Increased to handle Page Up/Down (ESC [ 5 ~ / ESC [ 6 ~)
		n, err := os.read(os.stdin, buf[:])

		if err != nil || n == 0 {
			return nil
		}

		result := Key_Event {
			key  = .Char,
			char = rune(buf[0]),
			shift = false,
		}

		
		// Handle escape sequences
		if buf[0] == 27 && n > 1 { 	// ESC
			if buf[1] == '[' {
				if n == 3 {
					switch buf[2] {
					case 'A':
						result.key = .Up
					case 'B':
						result.key = .Down
					case 'C':
						result.key = .Right
					case 'D':
						result.key = .Left
					}
					return result
				} else if n == 4 && buf[2] == 'Z' {
					// Shift+Tab combination: ESC [ Z
					result.key = .Tab
					result.shift = true
					return result
				} else if n == 5 && buf[2] == '5' && buf[3] == '~' {
					// Page Up: ESC [ 5 ~
					result.key = .PageUp
					return result
				} else if n == 5 && buf[2] == '6' && buf[3] == '~' {
					// Page Down: ESC [ 6 ~
					result.key = .PageDown
					return result
				}
			}
			result.key = .Escape
			return result
		}

		switch buf[0] {
		case 13, 10:
			// CR and LF (Enter key can be either)
			result.key = .Enter
		case 127:
			result.key = .Backspace
		case 9:
			result.key = .Tab
		}

		return result
	}

	return nil
}
