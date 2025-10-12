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
}

Key_Event :: struct {
	key:  Key,
	char: rune,
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

			result := Key_Event {
				key  = .Char,
				char = rune(ch),
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
			}

			return result
		}
	} else {
		buf: [3]byte
		n, err := os.read(os.stdin, buf[:])

		if err != nil || n == 0 {
			return nil
		}

		result := Key_Event {
			key  = .Char,
			char = rune(buf[0]),
		}

		// Handle escape sequences
		if buf[0] == 27 && n > 1 { 	// ESC
			if buf[1] == '[' && n == 3 {
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
