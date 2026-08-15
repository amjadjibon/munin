package munin

import "core:testing"
import "core:time"

// The input parser under test is the POSIX one; the Windows port reads
// console records instead and shares none of this code.
when ODIN_OS != .Windows {

// ============================================================
// INPUT TESTS - Keyboard and Mouse Event Parsing
// ============================================================

// ============================================================
// MOUSE EVENT PARSING TESTS (SGR format)
// ============================================================

@(test)
test_parse_sgr_mouse_left_click :: proc(t: ^testing.T) {
	// ESC [ < 0 ; 10 ; 20 M (left button press at 10,20)
	buf := []byte{27, '[', '<', '0', ';', '1', '0', ';', '2', '0', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, ok, "Should parse left click")
	testing.expect_value(t, event.button, Mouse_Button.Left)
	testing.expect_value(t, event.type, Mouse_Event_Type.Press)
	testing.expect_value(t, event.x, 9) // 0-based (10-1)
	testing.expect_value(t, event.y, 19) // 0-based (20-1)
	testing.expect_value(t, event.shift, false)
	testing.expect_value(t, event.ctrl, false)
	testing.expect_value(t, event.alt, false)
}

@(test)
test_parse_sgr_mouse_left_release :: proc(t: ^testing.T) {
	// ESC [ < 0 ; 10 ; 20 m (left button release)
	buf := []byte{27, '[', '<', '0', ';', '1', '0', ';', '2', '0', 'm'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, ok, "Should parse left release")
	testing.expect_value(t, event.button, Mouse_Button.Left)
	testing.expect_value(t, event.type, Mouse_Event_Type.Release)
}

@(test)
test_parse_sgr_mouse_right_click :: proc(t: ^testing.T) {
	// ESC [ < 2 ; 5 ; 10 M (right button press)
	buf := []byte{27, '[', '<', '2', ';', '5', ';', '1', '0', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, ok, "Should parse right click")
	testing.expect_value(t, event.button, Mouse_Button.Right)
	testing.expect_value(t, event.type, Mouse_Event_Type.Press)
	testing.expect_value(t, event.x, 4)
	testing.expect_value(t, event.y, 9)
}

@(test)
test_parse_sgr_mouse_middle_click :: proc(t: ^testing.T) {
	// ESC [ < 1 ; 15 ; 25 M (middle button press)
	buf := []byte{27, '[', '<', '1', ';', '1', '5', ';', '2', '5', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, ok, "Should parse middle click")
	testing.expect_value(t, event.button, Mouse_Button.Middle)
	testing.expect_value(t, event.type, Mouse_Event_Type.Press)
	testing.expect_value(t, event.x, 14)
	testing.expect_value(t, event.y, 24)
}

@(test)
test_parse_sgr_mouse_wheel_up :: proc(t: ^testing.T) {
	// ESC [ < 64 ; 10 ; 10 M (wheel up)
	buf := []byte{27, '[', '<', '6', '4', ';', '1', '0', ';', '1', '0', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, ok, "Should parse wheel up")
	testing.expect_value(t, event.button, Mouse_Button.WheelUp)
	testing.expect_value(t, event.type, Mouse_Event_Type.Press)
}

@(test)
test_parse_sgr_mouse_wheel_down :: proc(t: ^testing.T) {
	// ESC [ < 65 ; 10 ; 10 M (wheel down)
	buf := []byte{27, '[', '<', '6', '5', ';', '1', '0', ';', '1', '0', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, ok, "Should parse wheel down")
	testing.expect_value(t, event.button, Mouse_Button.WheelDown)
	testing.expect_value(t, event.type, Mouse_Event_Type.Press)
}

@(test)
test_parse_sgr_mouse_drag :: proc(t: ^testing.T) {
	// ESC [ < 32 ; 20 ; 30 M (left drag - button 0 + motion bit 32)
	buf := []byte{27, '[', '<', '3', '2', ';', '2', '0', ';', '3', '0', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, ok, "Should parse drag")
	testing.expect_value(t, event.button, Mouse_Button.Left)
	testing.expect_value(t, event.type, Mouse_Event_Type.Drag)
}

@(test)
test_parse_sgr_mouse_hover :: proc(t: ^testing.T) {
	// ESC [ < 35 ; 15 ; 15 M (hover/move - no button + motion bit)
	buf := []byte{27, '[', '<', '3', '5', ';', '1', '5', ';', '1', '5', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, ok, "Should parse hover")
	testing.expect_value(t, event.button, Mouse_Button.None)
	testing.expect_value(t, event.type, Mouse_Event_Type.Move)
}

@(test)
test_parse_sgr_mouse_with_shift :: proc(t: ^testing.T) {
	// ESC [ < 4 ; 10 ; 10 M (button 0 + shift bit 4)
	buf := []byte{27, '[', '<', '4', ';', '1', '0', ';', '1', '0', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, ok, "Should parse with shift")
	testing.expect_value(t, event.shift, true)
	testing.expect_value(t, event.button, Mouse_Button.Left)
}

@(test)
test_parse_sgr_mouse_with_alt :: proc(t: ^testing.T) {
	// ESC [ < 8 ; 10 ; 10 M (button 0 + alt bit 8)
	buf := []byte{27, '[', '<', '8', ';', '1', '0', ';', '1', '0', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, ok, "Should parse with alt")
	testing.expect_value(t, event.alt, true)
	testing.expect_value(t, event.button, Mouse_Button.Left)
}

@(test)
test_parse_sgr_mouse_with_ctrl :: proc(t: ^testing.T) {
	// ESC [ < 16 ; 10 ; 10 M (button 0 + ctrl bit 16)
	buf := []byte{27, '[', '<', '1', '6', ';', '1', '0', ';', '1', '0', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, ok, "Should parse with ctrl")
	testing.expect_value(t, event.ctrl, true)
	testing.expect_value(t, event.button, Mouse_Button.Left)
}

@(test)
test_parse_sgr_mouse_large_coordinates :: proc(t: ^testing.T) {
	// ESC [ < 0 ; 200 ; 150 M (large coordinates)
	buf := []byte{27, '[', '<', '0', ';', '2', '0', '0', ';', '1', '5', '0', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, ok, "Should parse large coordinates")
	testing.expect_value(t, event.x, 199) // 0-based
	testing.expect_value(t, event.y, 149) // 0-based
}

@(test)
test_parse_sgr_mouse_origin :: proc(t: ^testing.T) {
	// ESC [ < 0 ; 1 ; 1 M (at origin, 1-based)
	buf := []byte{27, '[', '<', '0', ';', '1', ';', '1', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, ok, "Should parse origin click")
	testing.expect_value(t, event.x, 0) // Converted to 0-based
	testing.expect_value(t, event.y, 0)
}

// ============================================================
// INVALID INPUT TESTS
// ============================================================

@(test)
test_parse_sgr_mouse_too_short :: proc(t: ^testing.T) {
	// Too short
	buf := []byte{27, '[', '<', '0'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, !ok, "Should reject too-short sequence")
}

@(test)
test_parse_sgr_mouse_not_escape :: proc(t: ^testing.T) {
	// Doesn't start with ESC
	buf := []byte{'A', '[', '<', '0', ';', '1', ';', '1', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, !ok, "Should reject non-escape sequence")
}

@(test)
test_parse_sgr_mouse_not_csi :: proc(t: ^testing.T) {
	// ESC but not [
	buf := []byte{27, 'A', '<', '0', ';', '1', ';', '1', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, !ok, "Should reject non-CSI sequence")
}

@(test)
test_parse_sgr_mouse_not_sgr :: proc(t: ^testing.T) {
	// ESC [ but not <
	buf := []byte{27, '[', 'A', '0', ';', '1', ';', '1', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, !ok, "Should reject non-SGR sequence")
}

@(test)
test_parse_sgr_mouse_missing_semicolons :: proc(t: ^testing.T) {
	// Missing semicolons
	buf := []byte{27, '[', '<', '0', '1', '0', '2', '0', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, !ok, "Should reject missing semicolons")
}

@(test)
test_parse_sgr_mouse_no_terminator :: proc(t: ^testing.T) {
	// No M or m terminator
	buf := []byte{27, '[', '<', '0', ';', '1', '0', ';', '2', '0'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, !ok, "Should reject missing terminator")
}

// ============================================================
// KEY EVENT TYPE TESTS
// ============================================================

@(test)
test_key_event_types :: proc(t: ^testing.T) {
	// Test that Key enum values exist and are distinct
	testing.expect(t, Key.Char != Key.Up, "Keys should be distinct")
	testing.expect(t, Key.Down != Key.Left, "Keys should be distinct")
	testing.expect(t, Key.Right != Key.Enter, "Keys should be distinct")
	testing.expect(t, Key.Escape != Key.Backspace, "Keys should be distinct")
	testing.expect(t, Key.Tab != Key.PageUp, "Keys should be distinct")
	testing.expect(t, Key.PageDown != Key.Unknown, "Keys should be distinct")
}

@(test)
test_mouse_button_types :: proc(t: ^testing.T) {
	// Test that Mouse_Button enum values exist and are distinct
	testing.expect(t, Mouse_Button.None != Mouse_Button.Left, "Buttons should be distinct")
	testing.expect(t, Mouse_Button.Right != Mouse_Button.Middle, "Buttons should be distinct")
	testing.expect(t, Mouse_Button.WheelUp != Mouse_Button.WheelDown, "Buttons should be distinct")
}

@(test)
test_mouse_event_type_values :: proc(t: ^testing.T) {
	// Test that Mouse_Event_Type enum values exist and are distinct
	testing.expect(
		t,
		Mouse_Event_Type.Press != Mouse_Event_Type.Release,
		"Event types should be distinct",
	)
	testing.expect(
		t,
		Mouse_Event_Type.Drag != Mouse_Event_Type.Move,
		"Event types should be distinct",
	)
}

// ============================================================
// INPUT EVENT UNION TESTS
// ============================================================

@(test)
test_input_event_union :: proc(t: ^testing.T) {
	// Test creating Input_Event with Key_Event
	key_event := Key_Event {
		key   = .Char,
		char  = 'a',
		shift = false,
	}
	input: Input_Event = key_event

	switch e in input {
	case Key_Event:
		testing.expect_value(t, e.key, Key.Char)
		testing.expect_value(t, e.char, 'a')
	case Mouse_Event:
		testing.fail_now(t, "Expected Key_Event, got Mouse_Event")
	}
}

@(test)
test_input_event_mouse :: proc(t: ^testing.T) {
	// Test creating Input_Event with Mouse_Event
	mouse_event := Mouse_Event {
		button = .Left,
		type   = .Press,
		x      = 10,
		y      = 20,
		shift  = false,
		ctrl   = false,
		alt    = false,
	}
	input: Input_Event = mouse_event

	switch e in input {
	case Key_Event:
		testing.fail_now(t, "Expected Mouse_Event, got Key_Event")
	case Mouse_Event:
		testing.expect_value(t, e.button, Mouse_Button.Left)
		testing.expect_value(t, e.type, Mouse_Event_Type.Press)
		testing.expect_value(t, e.x, 10)
		testing.expect_value(t, e.y, 20)
	}
}

// ============================================================
// EDGE CASES AND BOUNDARY TESTS
// ============================================================

@(test)
test_parse_sgr_mouse_all_modifiers :: proc(t: ^testing.T) {
	// All modifier bits set: shift(4) + alt(8) + ctrl(16) = 28
	// Button 0 + modifiers = 28
	buf := []byte{27, '[', '<', '2', '8', ';', '1', '0', ';', '1', '0', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, ok, "Should parse all modifiers")
	testing.expect_value(t, event.shift, true)
	testing.expect_value(t, event.alt, true)
	testing.expect_value(t, event.ctrl, true)
	testing.expect_value(t, event.button, Mouse_Button.Left)
}

@(test)
test_parse_sgr_mouse_right_drag :: proc(t: ^testing.T) {
	// Right button (2) + motion bit (32) = 34
	buf := []byte{27, '[', '<', '3', '4', ';', '1', '5', ';', '2', '5', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, ok, "Should parse right drag")
	testing.expect_value(t, event.button, Mouse_Button.Right)
	testing.expect_value(t, event.type, Mouse_Event_Type.Drag)
}

@(test)
test_parse_sgr_mouse_middle_drag :: proc(t: ^testing.T) {
	// Middle button (1) + motion bit (32) = 33
	buf := []byte{27, '[', '<', '3', '3', ';', '2', '0', ';', '3', '0', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, ok, "Should parse middle drag")
	testing.expect_value(t, event.button, Mouse_Button.Middle)
	testing.expect_value(t, event.type, Mouse_Event_Type.Drag)
}

@(test)
test_parse_sgr_mouse_wheel_with_modifiers :: proc(t: ^testing.T) {
	// Wheel up (64) + shift (4) = 68
	buf := []byte{27, '[', '<', '6', '8', ';', '1', '0', ';', '1', '0', 'M'}
	event, ok := parse_sgr_mouse(buf[:], len(buf)).?

	testing.expect(t, ok, "Should parse wheel with shift")
	testing.expect_value(t, event.button, Mouse_Button.WheelUp)
	testing.expect_value(t, event.shift, true)
}

// Helper to create byte slice from string for testing
to_bytes :: proc(s: string) -> []byte {
	return transmute([]byte)s
}

@(test)
test_parse_simple_char :: proc(t: ^testing.T) {
	input := to_bytes("A")
	event, consumed, ok := parse_event_from_buffer(input)

	testing.expect(t, ok, "Should have parsed event")
	testing.expect_value(t, consumed, 1)

	if ok {
		#partial switch e in event {
		case Key_Event:
			testing.expect_value(t, e.key, Key.Char)
			testing.expect_value(t, e.char, 'A')
		case:
			testing.expect(t, false, "Expected Key_Event")
		}
	}
}

@(test)
test_parse_multiple_chars :: proc(t: ^testing.T) {
	input := to_bytes("AB")
	event, consumed, ok := parse_event_from_buffer(input)

	testing.expect(t, ok, "Should have parsed event")
	testing.expect_value(t, consumed, 1)

	if ok {
		#partial switch e in event {
		case Key_Event:
			testing.expect_value(t, e.key, Key.Char)
			testing.expect_value(t, e.char, 'A')
		case:
			testing.expect(t, false, "Expected Key_Event")
		}
	}
}

@(test)
test_parse_utf8_char :: proc(t: ^testing.T) {
	input := to_bytes("é")
	event, consumed, ok := parse_event_from_buffer(input)

	testing.expect(t, ok, "Should parse complete UTF-8 event")
	testing.expect_value(t, consumed, 2)

	if ok {
		#partial switch e in event {
		case Key_Event:
			testing.expect_value(t, e.key, Key.Char)
			testing.expect_value(t, e.char, 'é')
		case:
			testing.expect(t, false, "Expected Key_Event")
		}
	}
}

@(test)
test_parse_incomplete_utf8_char :: proc(t: ^testing.T) {
	input := []byte{0xC3}
	event, consumed, ok := parse_event_from_buffer(input)

	testing.expect(t, !ok, "Should wait for the rest of an incomplete UTF-8 sequence")
	testing.expect_value(t, consumed, 0)
}

@(test)
test_parse_utf8_emoji :: proc(t: ^testing.T) {
	input := to_bytes("😀")
	event, consumed, ok := parse_event_from_buffer(input)

	testing.expect(t, ok, "Should parse complete emoji event")
	testing.expect_value(t, consumed, 4)

	if ok {
		#partial switch e in event {
		case Key_Event:
			testing.expect_value(t, e.key, Key.Char)
			testing.expect_value(t, e.char, '😀')
		case:
			testing.expect(t, false, "Expected Key_Event")
		}
	}
}

@(test)
test_parse_escape_sequence_up :: proc(t: ^testing.T) {
	input := to_bytes("\x1b[A")
	event, consumed, ok := parse_event_from_buffer(input)

	testing.expect(t, ok, "Should have parsed event")
	testing.expect_value(t, consumed, 3)

	if ok {
		#partial switch e in event {
		case Key_Event:
			testing.expect_value(t, e.key, Key.Up)
		case:
			testing.expect(t, false, "Expected Key_Event")
		}
	}
}

@(test)
test_parse_incomplete_escape :: proc(t: ^testing.T) {
	input := to_bytes("\x1b[")
	event, consumed, ok := parse_event_from_buffer(input)

	testing.expect(t, !ok, "Should NOT have parsed event (incomplete)")
	testing.expect_value(t, consumed, 0)
}

@(test)
test_parse_sgr_mouse :: proc(t: ^testing.T) {
	// Click left button at 10,20 (raw: <0;10;20M)
	input := to_bytes("\x1b[<0;10;20M")
	event, consumed, ok := parse_event_from_buffer(input)

	testing.expect(t, ok, "Should have parsed mouse event")
	testing.expect_value(t, consumed, 11) // ESC [ < 0 ; 1 0 ; 2 0 M (length 11)

	if ok {
		#partial switch e in event {
		case Mouse_Event:
			testing.expect_value(t, e.button, Mouse_Button.Left)
			testing.expect_value(t, e.x, 9) // 1-based to 0-based
			testing.expect_value(t, e.y, 19)
			testing.expect_value(t, e.type, Mouse_Event_Type.Press)
		case:
			testing.expect(t, false, "Expected Mouse_Event")
		}
	}
}

// ============================================================
// MALFORMED SEQUENCE HANDLING (REGRESSION)
// ============================================================

@(test)
test_parse_sgr_mouse_rejects_non_digits :: proc(t: ^testing.T) {
	// Non-digit bytes in the numeric fields used to be run through `b - '0'`,
	// producing arbitrary coordinates.
	buf := to_bytes("\x1b[<AAAAAAAA;BBBBBBBB;1M")
	_, ok := parse_sgr_mouse(buf, len(buf)).?
	testing.expect(t, !ok, "Should reject non-digit fields")
}

@(test)
test_parse_sgr_mouse_rejects_overlong_number :: proc(t: ^testing.T) {
	buf := to_bytes("\x1b[<0;99999999999999999999;1M")
	_, ok := parse_sgr_mouse(buf, len(buf)).?
	testing.expect(t, !ok, "Should reject an out-of-range coordinate")
}

@(test)
test_parse_sgr_mouse_zero_coordinate_clamped :: proc(t: ^testing.T) {
	buf := to_bytes("\x1b[<0;0;0M")
	event, ok := parse_sgr_mouse(buf, len(buf)).?
	testing.expect(t, ok, "Should parse zero coordinates")
	testing.expect_value(t, event.x, 0)
	testing.expect_value(t, event.y, 0)
}

@(test)
test_parse_unknown_csi_is_fully_consumed :: proc(t: ^testing.T) {
	// F5 is ESC [ 1 5 ~. Consuming only the ESC left "[15~" to be delivered
	// to the application as four literal keystrokes.
	input := to_bytes("\x1b[15~")
	_, consumed, ok := parse_event_from_buffer(input)
	testing.expect(t, ok, "Should produce an event")
	testing.expect_value(t, consumed, 5)
}

@(test)
test_parse_bracketed_paste_marker_consumed :: proc(t: ^testing.T) {
	input := to_bytes("\x1b[200~")
	event, consumed, ok := parse_event_from_buffer(input)
	testing.expect(t, ok, "Should produce an event")
	testing.expect_value(t, consumed, 6)

	if ok {
		#partial switch e in event {
		case Key_Event:
			testing.expect_value(t, e.key, Key.Unknown)
		case:
			testing.expect(t, false, "Expected Key_Event")
		}
	}
}

@(test)
test_parse_modified_arrow_key :: proc(t: ^testing.T) {
	// Ctrl+Up: ESC [ 1 ; 5 A
	input := to_bytes("\x1b[1;5A")
	event, consumed, ok := parse_event_from_buffer(input)
	testing.expect(t, ok, "Should parse modified arrow")
	testing.expect_value(t, consumed, 6)

	if ok {
		#partial switch e in event {
		case Key_Event:
			testing.expect_value(t, e.key, Key.Up)
			testing.expect_value(t, e.ctrl, true)
			testing.expect_value(t, e.shift, false)
		case:
			testing.expect(t, false, "Expected Key_Event")
		}
	}
}

@(test)
test_parse_ss3_arrow :: proc(t: ^testing.T) {
	// Application cursor mode sends ESC O A for Up
	input := to_bytes("\x1bOA")
	event, consumed, ok := parse_event_from_buffer(input)
	testing.expect(t, ok, "Should parse SS3 arrow")
	testing.expect_value(t, consumed, 3)

	if ok {
		#partial switch e in event {
		case Key_Event:
			testing.expect_value(t, e.key, Key.Up)
		case:
			testing.expect(t, false, "Expected Key_Event")
		}
	}
}

@(test)
test_parse_alt_char :: proc(t: ^testing.T) {
	input := to_bytes("\x1ba")
	event, consumed, ok := parse_event_from_buffer(input)
	testing.expect(t, ok, "Should parse Alt+a")
	testing.expect_value(t, consumed, 2)

	if ok {
		#partial switch e in event {
		case Key_Event:
			testing.expect_value(t, e.key, Key.Char)
			testing.expect_value(t, e.char, 'a')
			testing.expect_value(t, e.alt, true)
		case:
			testing.expect(t, false, "Expected Key_Event")
		}
	}
}

@(test)
test_parse_ctrl_c :: proc(t: ^testing.T) {
	input := []byte{3}
	event, consumed, ok := parse_event_from_buffer(input)
	testing.expect(t, ok, "Should parse Ctrl+C")
	testing.expect_value(t, consumed, 1)

	if ok {
		#partial switch e in event {
		case Key_Event:
			testing.expect_value(t, e.char, 'c')
			testing.expect_value(t, e.ctrl, true)
		case:
			testing.expect(t, false, "Expected Key_Event")
		}
	}
}

// ============================================================
// INPUT BUFFER (chunked reads, timeouts, overflow)
// ============================================================

@(private = "file")
feed_str :: proc(b: ^Input_Buffer, s: string, at: time.Time) -> int {
	return input_buffer_feed(b, transmute([]byte)s, at)
}

@(test)
test_input_buffer_parses_events_in_order :: proc(t: ^testing.T) {
	b: Input_Buffer
	now := time.now()
	feed_str(&b, "ab", now)

	first, ok1 := input_buffer_next(&b, now).?
	second, ok2 := input_buffer_next(&b, now).?
	_, ok3 := input_buffer_next(&b, now).?

	testing.expect(t, ok1 && ok2, "two characters, two events")
	testing.expect(t, !ok3, "and then nothing")
	testing.expect_value(t, first.(Key_Event).char, 'a')
	testing.expect_value(t, second.(Key_Event).char, 'b')
}

@(test)
test_input_buffer_waits_for_a_split_escape_sequence :: proc(t: ^testing.T) {
	// A sequence arriving in two reads must not be misparsed as Escape plus
	// literal characters.
	b: Input_Buffer
	now := time.now()

	feed_str(&b, "\x1b[", now)
	_, early := input_buffer_next(&b, now).?
	testing.expect(t, !early, "incomplete sequence should wait")

	feed_str(&b, "A", now)
	event, ok := input_buffer_next(&b, now).?
	testing.expect(t, ok, "completed sequence should parse")
	testing.expect_value(t, event.(Key_Event).key, Key.Up)
}

@(test)
test_input_buffer_split_utf8_character :: proc(t: ^testing.T) {
	b: Input_Buffer
	now := time.now()

	feed_str(&b, "\xc3", now) // first byte of "é"
	_, early := input_buffer_next(&b, now).?
	testing.expect(t, !early, "incomplete character should wait")

	feed_str(&b, "\xa9", now)
	event, ok := input_buffer_next(&b, now).?
	testing.expect(t, ok, "completed character should parse")
	testing.expect_value(t, event.(Key_Event).char, 'é')
}

@(test)
test_input_buffer_bare_escape_resolves_on_timeout :: proc(t: ^testing.T) {
	b: Input_Buffer
	now := time.now()
	feed_str(&b, "\x1b", now)

	_, early := input_buffer_next(&b, now).?
	testing.expect(t, !early, "a lone ESC is ambiguous at first")

	later := time.time_add(now, ESCAPE_TIMEOUT + time.Millisecond)
	event, ok := input_buffer_next(&b, later).?
	testing.expect(t, ok, "after the timeout it is the Escape key")
	testing.expect_value(t, event.(Key_Event).key, Key.Escape)
	testing.expect_value(t, b.len, 0)
}

@(test)
test_input_buffer_recovers_immediately_when_full :: proc(t: ^testing.T) {
	// A full buffer holding an unterminated sequence cannot be resolved by
	// waiting - nothing more can be read into it.
	b: Input_Buffer
	now := time.now()

	junk := make([]byte, len(b.data), context.temp_allocator)
	junk[0] = 0x1b
	junk[1] = '['
	for i in 2 ..< len(junk) {
		junk[i] = '9' // parameter bytes: the sequence never terminates
	}
	accepted := input_buffer_feed(&b, junk, now)
	testing.expect_value(t, accepted, len(b.data))

	// No waiting: it must make progress on this very call.
	_, ok := input_buffer_next(&b, now).?
	testing.expect(t, ok, "a full buffer must resolve without waiting")
	testing.expect(t, b.len < len(b.data), "and must consume something")
	free_all(context.temp_allocator)
}

@(test)
test_input_buffer_feed_drops_what_does_not_fit :: proc(t: ^testing.T) {
	b: Input_Buffer
	now := time.now()

	first := make([]byte, len(b.data), context.temp_allocator)
	for i in 0 ..< len(first) {
		first[i] = 'x'
	}
	testing.expect_value(t, input_buffer_feed(&b, first, now), len(b.data))
	testing.expect_value(t, input_buffer_feed(&b, first, now), 0) // no room left
	free_all(context.temp_allocator)
}

@(test)
test_input_buffer_drains_a_paste_in_one_pass :: proc(t: ^testing.T) {
	// The run loop drains in a loop; a pasted line must come out as events
	// without any waiting in between.
	b: Input_Buffer
	now := time.now()
	text := "the quick brown fox"
	feed_str(&b, text, now)

	count := 0
	for {
		event, ok := input_buffer_next(&b, now).?
		if !ok {
			break
		}
		if key, is_key := event.(Key_Event); is_key && key.key == .Char {
			count += 1
		}
	}

	testing.expect_value(t, count, len(text))
	testing.expect_value(t, b.len, 0)
}

@(test)
test_input_buffer_mixed_stream :: proc(t: ^testing.T) {
	// Text, a mouse report and an arrow key in one read.
	b: Input_Buffer
	now := time.now()
	feed_str(&b, "a\x1b[<0;10;20M\x1b[B", now)

	kinds := make([dynamic]string, context.temp_allocator)
	for {
		event, ok := input_buffer_next(&b, now).?
		if !ok {
			break
		}
		switch e in event {
		case Key_Event:
			append(&kinds, e.key == .Char ? "char" : "key")
		case Mouse_Event:
			append(&kinds, "mouse")
		}
	}

	testing.expect_value(t, len(kinds), 3)
	testing.expect_value(t, kinds[0], "char")
	testing.expect_value(t, kinds[1], "mouse")
	testing.expect_value(t, kinds[2], "key")
	free_all(context.temp_allocator)
}
}

