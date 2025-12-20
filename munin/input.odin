package munin


import "core:os"
import win32 "core:sys/windows"

@(private)
input_buffer: [1024]byte
@(private)
input_buffer_len: int


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
	key:   Key,
	char:  rune,
	shift: bool,
	ctrl:  bool,
	alt:   bool,
}

// Mouse button types
Mouse_Button :: enum {
	None,
	Left,
	Right,
	Middle,
	WheelUp,
	WheelDown,
}

// Mouse event types
Mouse_Event_Type :: enum {
	Press,
	Release,
	Drag,
	Move,
}

// Mouse event structure
Mouse_Event :: struct {
	button: Mouse_Button,
	type:   Mouse_Event_Type,
	x:      int,
	y:      int,
	shift:  bool,
	ctrl:   bool,
	alt:    bool,
}

// Input event can be either keyboard or mouse
Input_Event :: union {
	Key_Event,
	Mouse_Event,
}


// Helper: Parse a single event from a buffer
// Returns: event, consumed_bytes, success
parse_event_from_buffer :: proc(buf: []byte) -> (Input_Event, int, bool) {
	if len(buf) == 0 {
		return nil, 0, false
	}

	// Handle Escape Sequences
	if buf[0] == 0x1b {
		// Just ESC?
		if len(buf) == 1 {
			// We can't know if it's just ESC or start of sequence without waiting.
			// But for responsiveness, if we only have ESC, we might want to wait a bit
			// or assume ESC if enough time passed.
			// For now, in a non-blocking poll, this is tricky.
			// Standard approach: if we read ESC and nothing else follows *immediately*, it's ESC.
			// But since we are buffering, 'immediately' is relative.
			// Let's assume for now if it's just ESC in buffer, we wait for more (return false)
			// UNLESS we are sure no more data is coming (which we can't be).
			// TODO: Implement proper timeout for ESC key.
			// validation: if the user pressed ESC, we need to return it eventually.
			// For now, let's treat single ESC as partial sequence unless followed by invalid char.
			return nil, 0, false
		}

		if buf[1] == '[' {
			if len(buf) < 3 {
				return nil, 0, false
			}

			// Mouse SGR: ESC [ < ...
			if buf[2] == '<' {
				// We need to find the 'm' or 'M' terminator
				end_idx := -1
				for i in 3 ..< len(buf) {
					if buf[i] == 'm' || buf[i] == 'M' {
						end_idx = i
						break
					}
				}
				if end_idx == -1 {
					// Incomplete mouse sequence
					return nil, 0, false
				}

				// Apply limit check for sanity (e.g. max mouse seq length ~32)
				if end_idx > 32 {
					// Garbage or too long, consume 1 byte (ESC) and retry
					return nil, 1, false // Actually we should fail this invalid sequence
				}

				// Parse using existing helper (adapted)
				if mouse, ok := parse_sgr_mouse(buf[:end_idx + 1], end_idx + 1).?; ok {
					return mouse, end_idx + 1, true
				} else {
					// Failed to parse, consume ESC
					// Or consume whole sequence as garbage?
					// Safer to consume ESC
					return Key_Event{key = .Escape}, 1, true
				}
			}

			// Regular CSI sequences

			// Arrow keys: ESC [ A/B/C/D
			switch buf[2] {
			case 'A':
				return Key_Event{key = .Up}, 3, true
			case 'B':
				return Key_Event{key = .Down}, 3, true
			case 'C':
				return Key_Event{key = .Right}, 3, true
			case 'D':
				return Key_Event{key = .Left}, 3, true
			case 'Z':
				return Key_Event{key = .Tab, shift = true}, 3, true // Shift+Tab
			}

			// Page Up/Down: ESC [ 5 ~ / ESC [ 6 ~
			if len(buf) >= 4 {
				if buf[2] == '5' && buf[3] == '~' {
					return Key_Event{key = .PageUp}, 4, true
				}
				if buf[2] == '6' && buf[3] == '~' {
					return Key_Event{key = .PageDown}, 4, true
				}
			} else {
				// Might be incomplete 5~
				if buf[2] == '5' || buf[2] == '6' {
					return nil, 0, false
				}
			}

			// Unknown CSI
			return Key_Event{key = .Escape}, 1, true
		}

		// ESC followed by something else (e.g. Meta/Alt key)
		// For now, treat as ESC
		return Key_Event{key = .Escape}, 1, true
	}

	// Regular characters
	// Handle Control characters
	switch buf[0] {
	case 13, 10:
		return Key_Event{key = .Enter}, 1, true
	case 127:
		return Key_Event{key = .Backspace}, 1, true
	case 9:
		return Key_Event{key = .Tab}, 1, true
	case 3:
		return Key_Event{key = .Char, char = 'c', ctrl = true}, 1, true // Ctrl+C (often trapped by signal, but if raw)
	}

	// Default char
	return Key_Event{key = .Char, char = rune(buf[0]), shift = false}, 1, true
}

read_key :: proc() -> Maybe(Key_Event) {
	// Reuse read_input and filter
	if event, ok := read_input().?; ok {
		#partial switch e in event {
		case Key_Event:
			return e
		}
	}
	return nil
}

// ============================================================
// MOUSE INPUT
// ============================================================

// Parse SGR mouse event (format: ESC [ < Cb ; Cx ; Cy M/m)
// This is the preferred format with better coordinate support
parse_sgr_mouse :: proc(buf: []byte, n: int) -> Maybe(Mouse_Event) {
	if n < 9 || buf[0] != 27 || buf[1] != '[' || buf[2] != '<' {
		return nil
	}

	// Find semicolons and M/m terminator
	semi1, semi2, end := -1, -1, -1
	for i in 3 ..< n {
		if buf[i] == ';' {
			if semi1 == -1 {
				semi1 = i
			} else if semi2 == -1 {
				semi2 = i
			}
		} else if buf[i] == 'M' || buf[i] == 'm' {
			end = i
			break
		}
	}

	if semi1 == -1 || semi2 == -1 || end == -1 {
		return nil
	}

	// Parse Cb (button + modifiers)
	cb := 0
	for i in 3 ..< semi1 {
		cb = cb * 10 + int(buf[i] - '0')
	}

	// Parse Cx (x coordinate, 1-based)
	cx := 0
	for i in (semi1 + 1) ..< semi2 {
		cx = cx * 10 + int(buf[i] - '0')
	}

	// Parse Cy (y coordinate, 1-based)
	cy := 0
	for i in (semi2 + 1) ..< end {
		cy = cy * 10 + int(buf[i] - '0')
	}

	// Determine event type (M = press, m = release)
	event_type := Mouse_Event_Type.Press if buf[end] == 'M' else .Release

	// Extract modifiers from high bits
	shift := (cb & 0x04) != 0
	alt := (cb & 0x08) != 0
	ctrl := (cb & 0x10) != 0
	motion := (cb & 0x20) != 0 // Bit 5 indicates motion/drag

	button: Mouse_Button

	// Check for wheel events first (codes 64-65 base, with modifiers in high bits)
	// Wheel events have bit pattern: 64 (0x40) for up, 65 (0x41) for down
	base_code := cb & 0x43 // Mask to get base wheel code
	if base_code == 64 || base_code == 65 {
		button = .WheelUp if base_code == 64 else .WheelDown
		event_type = .Press
	} else {
		// Regular button events - extract from low 2 bits
		button_code := cb & 0x03
		switch button_code {
		case 0:
			button = .Left
		case 1:
			button = .Middle
		case 2:
			button = .Right
		case 3:
			// Button 3 with motion bit typically means hover (no button pressed)
			button = .None
		}
	}

	// Determine if this is drag or hover based on motion bit and button state
	if motion && event_type == .Press {
		if button == .None {
			// Motion with no button = hover
			event_type = .Move
		} else {
			// Motion with button = drag
			event_type = .Drag
		}
	}

	return Mouse_Event {
		button = button,
		type   = event_type,
		x      = cx - 1, // Convert to 0-based
		y      = cy - 1,
		shift  = shift,
		ctrl   = ctrl,
		alt    = alt,
	}
}

// Read input event (keyboard or mouse)
read_input :: proc() -> Maybe(Input_Event) {
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
	} else {
		// Unix/Linux/macOS

		// 1. Read available input into buffer
		// Only read if we have space
		if input_buffer_len < len(input_buffer) {
			// Read into available space
			available_buf := input_buffer[input_buffer_len:]
			n, err := os.read(os.stdin, available_buf) // Non-blocking because VMIN=0/VTIME=0
			if err == nil && n > 0 {
				input_buffer_len += n
			}
		}

		if input_buffer_len == 0 {
			return nil
		}

		// 2. Parse event
		event, consumed, ok := parse_event_from_buffer(input_buffer[:input_buffer_len])

		if ok {
			// Shift remaining buffer
			copy(input_buffer[:], input_buffer[consumed:input_buffer_len])
			input_buffer_len -= consumed
			return event
		} else {
			// Incomplete sequence or waiting for more data
			// We keep the data in the buffer for next time
			return nil
		}
	}

	return nil
}
