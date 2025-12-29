package munin

import win32 "core:sys/windows"

when ODIN_OS == .Windows {

	read_input :: proc() -> Maybe(Input_Event) {
		stdin := win32.GetStdHandle(win32.STD_INPUT_HANDLE)
		events_read: win32.DWORD
		event: win32.INPUT_RECORD

		if !win32.PeekConsoleInputW(stdin, &event, 1, &events_read) || events_read == 0 {
			return nil
		}

		if !win32.ReadConsoleInputW(stdin, &event, 1, &events_read) {
			return nil
		}

		// Handle keyboard events
		if event.EventType == win32.KEY_EVENT && event.Event.KeyEvent.bKeyDown {
			vk := event.Event.KeyEvent.wVirtualKeyCode
			ch := event.Event.KeyEvent.uChar.UnicodeChar
			shift_key_state := event.Event.KeyEvent.dwControlKeyState & win32.SHIFT_PRESSED != 0

			result := Key_Event {
				key   = .Char,
				char  = rune(ch),
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

		// Handle mouse events
		if event.EventType == win32.MOUSE_EVENT {
			mouse := event.Event.MouseEvent
			pos := mouse.dwMousePosition
			button_state := mouse.dwButtonState
			event_flags := mouse.dwEventFlags
			ctrl_key_state := mouse.dwControlKeyState

			// Determine button
			button: Mouse_Button = .None
			if button_state & win32.FROM_LEFT_1ST_BUTTON_PRESSED != 0 {
				button = .Left
			} else if button_state & win32.RIGHTMOST_BUTTON_PRESSED != 0 {
				button = .Right
			} else if button_state & win32.FROM_LEFT_2ND_BUTTON_PRESSED != 0 {
				button = .Middle
			}

			// Determine event type
			mouse_event_type: Mouse_Event_Type
			if event_flags & win32.MOUSE_MOVED != 0 {
				mouse_event_type = .Move if button == .None else .Drag
			} else if event_flags & win32.MOUSE_WHEELED != 0 {
				// Wheel direction is in high word of button_state
				wheel_delta := i32(button_state >> 16)
				button = .WheelUp if wheel_delta > 0 else .WheelDown
				mouse_event_type = .Press
			} else {
				// Press or release based on button state
				mouse_event_type = .Press if button != .None else .Release
			}

			return Mouse_Event {
				button = button,
				type = mouse_event_type,
				x = int(pos.X),
				y = int(pos.Y),
				shift = ctrl_key_state & win32.SHIFT_PRESSED != 0,
				ctrl = ctrl_key_state & (win32.LEFT_CTRL_PRESSED | win32.RIGHT_CTRL_PRESSED) != 0,
				alt = ctrl_key_state & (win32.LEFT_ALT_PRESSED | win32.RIGHT_ALT_PRESSED) != 0,
			}
		}

		return nil
	}
}
