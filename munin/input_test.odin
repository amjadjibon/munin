package munin

import "core:testing"

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
	testing.expect_value(t, event.x, 9)  // 0-based (10-1)
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
	testing.expect(t, Mouse_Event_Type.Press != Mouse_Event_Type.Release, "Event types should be distinct")
	testing.expect(t, Mouse_Event_Type.Drag != Mouse_Event_Type.Move, "Event types should be distinct")
}

// ============================================================
// INPUT EVENT UNION TESTS
// ============================================================

@(test)
test_input_event_union :: proc(t: ^testing.T) {
	// Test creating Input_Event with Key_Event
	key_event := Key_Event{key = .Char, char = 'a', shift = false}
	input: Input_Event = key_event

	switch e in input {
	case Key_Event:
		testing.expect_value(t, e.key, Key.Char)
		testing.expect_value(t, e.char, 'a')
	case Mouse_Event:
		testing.fail(t, "Expected Key_Event, got Mouse_Event")
	}
}

@(test)
test_input_event_mouse :: proc(t: ^testing.T) {
	// Test creating Input_Event with Mouse_Event
	mouse_event := Mouse_Event{
		button = .Left,
		type = .Press,
		x = 10,
		y = 20,
		shift = false,
		ctrl = false,
		alt = false,
	}
	input: Input_Event = mouse_event

	switch e in input {
	case Key_Event:
		testing.fail(t, "Expected Mouse_Event, got Key_Event")
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
