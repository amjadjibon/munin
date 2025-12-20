package components

import munin "../munin"
import "core:fmt"
import "core:strings"

// ============================================================
// TEXT INPUT COMPONENT
// ============================================================

Input_Style :: enum {
	Plain, // Simple underline
	Box, // Box around input
	Inline, // No border
}

Input_State :: struct {
	buffer:             [dynamic]u8,
	cursor_pos:         int,
	is_focused:         bool,
	is_password:        bool,
	max_length:         int,
	placeholder:        string,
	cursor_blink_state: bool,
}

// Create a new input state
make_input_state :: proc(max_length: int = 256, placeholder: string = "") -> Input_State {
	return Input_State {
		buffer = make([dynamic]u8, 0, max_length),
		cursor_pos = 0,
		is_focused = false,
		is_password = false,
		max_length = max_length,
		placeholder = placeholder,
		cursor_blink_state = true,
	}
}

// Destroy input state
destroy_input_state :: proc(state: ^Input_State) {
	delete(state.buffer)
}

// Add character to input
input_add_char :: proc(state: ^Input_State, char: rune) {
	if len(state.buffer) >= state.max_length {
		return
	}

	// Convert rune to UTF-8
	buf: [4]u8
	n := utf8_encode_rune(buf[:], char)

	// Insert at cursor position
	for i in 0 ..< n {
		inject_at(&state.buffer, state.cursor_pos, buf[i])
		state.cursor_pos += 1
	}
}

// Remove character before cursor (backspace)
input_backspace :: proc(state: ^Input_State) {
	if state.cursor_pos > 0 && len(state.buffer) > 0 {
		ordered_remove(&state.buffer, state.cursor_pos - 1)
		state.cursor_pos -= 1
	}
}

// Remove character at cursor (delete)
input_delete :: proc(state: ^Input_State) {
	if state.cursor_pos < len(state.buffer) {
		ordered_remove(&state.buffer, state.cursor_pos)
	}
}

// Move cursor left
input_cursor_left :: proc(state: ^Input_State) {
	state.cursor_pos = max(0, state.cursor_pos - 1)
}

// Move cursor right
input_cursor_right :: proc(state: ^Input_State) {
	state.cursor_pos = min(len(state.buffer), state.cursor_pos + 1)
}

// Move cursor to start
input_cursor_home :: proc(state: ^Input_State) {
	state.cursor_pos = 0
}

// Move cursor to end
input_cursor_end :: proc(state: ^Input_State) {
	state.cursor_pos = len(state.buffer)
}

// Toggle cursor blink state
input_toggle_cursor_blink :: proc(state: ^Input_State) {
	state.cursor_blink_state = !state.cursor_blink_state
}

// Get current input text length
input_get_length :: proc(state: ^Input_State) -> int {
	return len(state.buffer)
}

// Check if input is empty
input_is_empty :: proc(state: ^Input_State) -> bool {
	return len(state.buffer) == 0
}

// Validate email format (basic check)
input_is_valid_email :: proc(state: ^Input_State) -> bool {
	text := input_get_text(state)
	if len(text) < 5 {
		return false
	}

	// Basic email validation: contains @ and . after @
	at_pos := strings.index_byte(text, '@')
	if at_pos == -1 || at_pos == 0 {
		return false
	}

	dot_pos := strings.index_byte(text[at_pos + 1:], '.')
	return dot_pos != -1
}

// Validate phone number format (basic check)
input_is_valid_phone :: proc(state: ^Input_State) -> bool {
	text := input_get_text(state)
	if len(text) < 10 {
		return false
	}

	// Check if contains only digits and basic phone characters
	for char in text {
		if !('0' <= char && char <= '9') &&
		   char != '-' &&
		   char != '(' &&
		   char != ')' &&
		   char != ' ' {
			return false
		}
	}
	return true
}

// Get current input text
input_get_text :: proc(state: ^Input_State) -> string {
	return string(state.buffer[:])
}

// Clear input
input_clear :: proc(state: ^Input_State) {
	clear(&state.buffer)
	state.cursor_pos = 0
}

// Helper to encode rune to UTF-8
@(private)
utf8_encode_rune :: proc(buf: []u8, r: rune) -> int {
	if r <= 0x7F {
		buf[0] = u8(r)
		return 1
	} else if r <= 0x7FF {
		buf[0] = 0xC0 | u8(r >> 6)
		buf[1] = 0x80 | u8(r & 0x3F)
		return 2
	} else if r <= 0xFFFF {
		buf[0] = 0xE0 | u8(r >> 12)
		buf[1] = 0x80 | u8((r >> 6) & 0x3F)
		buf[2] = 0x80 | u8(r & 0x3F)
		return 3
	} else {
		buf[0] = 0xF0 | u8(r >> 18)
		buf[1] = 0x80 | u8((r >> 12) & 0x3F)
		buf[2] = 0x80 | u8((r >> 6) & 0x3F)
		buf[3] = 0x80 | u8(r & 0x3F)
		return 4
	}
}

// Draw text input field
draw_input :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	state: ^Input_State,
	width: int,
	style: Input_Style = .Box,
	label: string = "",
	label_color: munin.Color = munin.Basic_Color.BrightYellow,
	text_color: munin.Color = munin.Basic_Color.White,
	cursor_color: munin.Color = munin.Basic_Color.BrightGreen,
	placeholder_color: munin.Color = munin.Basic_Color.BrightBlue,
) {
	current_x := pos.x
	current_y := pos.y

	// Draw label if provided
	if len(label) > 0 {
		munin.print_at(buf, {current_x, current_y}, label, label_color)
		current_y += 1
	}

	// Draw input box based on style
	switch style {
	case .Box:
		// Top border
		munin.move_cursor(buf, {current_x, current_y})
		munin.set_color(
			buf,
			state.is_focused ? munin.Basic_Color.BrightCyan : munin.Basic_Color.White,
		)
		strings.write_string(buf, "┌")
		for i in 0 ..< width - 2 {
			strings.write_string(buf, "─")
		}
		strings.write_string(buf, "┐")
		munin.reset_style(buf)
		current_y += 1

		// Input area
		munin.move_cursor(buf, {current_x, current_y})
		munin.set_color(
			buf,
			state.is_focused ? munin.Basic_Color.BrightCyan : munin.Basic_Color.White,
		)
		strings.write_string(buf, "│")
		munin.reset_style(buf)

		// Draw text content
		draw_input_content(
			buf,
			{current_x + 1, current_y},
			state,
			width - 2,
			text_color,
			cursor_color,
			placeholder_color,
		)

		munin.move_cursor(buf, {current_x + width - 1, current_y})
		munin.set_color(
			buf,
			state.is_focused ? munin.Basic_Color.BrightCyan : munin.Basic_Color.White,
		)
		strings.write_string(buf, "│")
		munin.reset_style(buf)
		current_y += 1

		// Bottom border
		munin.move_cursor(buf, {current_x, current_y})
		munin.set_color(
			buf,
			state.is_focused ? munin.Basic_Color.BrightCyan : munin.Basic_Color.White,
		)
		strings.write_string(buf, "└")
		for i in 0 ..< width - 2 {
			strings.write_string(buf, "─")
		}
		strings.write_string(buf, "┘")
		munin.reset_style(buf)

	case .Plain:
		// Draw text
		draw_input_content(
			buf,
			{current_x, current_y},
			state,
			width,
			text_color,
			cursor_color,
			placeholder_color,
		)
		current_y += 1

		// Draw underline
		munin.move_cursor(buf, {current_x, current_y})
		munin.set_color(
			buf,
			state.is_focused ? munin.Basic_Color.BrightCyan : munin.Basic_Color.White,
		)
		for i in 0 ..< width {
			strings.write_string(buf, "─")
		}
		munin.reset_style(buf)

	case .Inline:
		// Just draw text
		draw_input_content(
			buf,
			{current_x, current_y},
			state,
			width,
			text_color,
			cursor_color,
			placeholder_color,
		)
	}
}

// Helper to draw input content
@(private)
draw_input_content :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	state: ^Input_State,
	width: int,
	text_color: munin.Color,
	cursor_color: munin.Color,
	placeholder_color: munin.Color,
) {
	munin.move_cursor(buf, pos)

	// Show placeholder if empty
	if len(state.buffer) == 0 {
		munin.set_color(buf, placeholder_color)
		placeholder_text := state.placeholder
		if len(placeholder_text) > width {
			placeholder_text = placeholder_text[:width]
		}

		// Show placeholder text
		strings.write_string(buf, placeholder_text)

		// Show blinking cursor at start if focused
		if state.is_focused {
			munin.move_cursor(buf, pos)
			if state.cursor_blink_state {
				// Show cursor block
				munin.set_color(buf, cursor_color)
				strings.write_string(buf, "█")
			} else {
				// Show first character of placeholder when cursor is "off"
				if len(placeholder_text) > 0 {
					munin.set_color(buf, placeholder_color)
					strings.write_byte(buf, u8(placeholder_text[0]))
				} else {
					munin.set_color(buf, cursor_color)
					strings.write_string(buf, "_")
				}
			}
		}
		munin.reset_style(buf)
		return
	}

	// Draw text
	text := input_get_text(state)
	display_text := text
	if state.is_password {
		// Mask password
		masked := strings.repeat("*", len(text))
		display_text = masked
	}

	// Truncate if too long
	if len(display_text) > width {
		display_text = display_text[:width]
	}

	munin.set_color(buf, text_color)

	// Draw text with cursor
	for i in 0 ..< len(display_text) {
		if i == state.cursor_pos && state.is_focused {
			if state.cursor_blink_state {
				// Show cursor block
				munin.set_color(buf, cursor_color)
				strings.write_string(buf, "█")
			} else {
				// Show actual character when cursor is "off"
				munin.set_color(buf, text_color)
				strings.write_byte(buf, display_text[i])
			}
		} else {
			strings.write_byte(buf, display_text[i])
		}
	}

	// Draw cursor at end if needed
	if state.cursor_pos >= len(display_text) && state.is_focused {
		if state.cursor_blink_state {
			munin.set_color(buf, cursor_color)
			strings.write_string(buf, "█")
		} else {
			munin.set_color(buf, text_color)
			strings.write_string(buf, " ")
		}
	}

	munin.reset_style(buf)
}

// Draw multiple input fields (form)
draw_input_form :: proc(buf: ^strings.Builder, pos: munin.Vec2i, fields: []struct {
		label: string,
		state: ^Input_State,
	}, focused_index: int, width: int = 40) {
	current_y := pos.y

	for field, i in fields {
		field.state.is_focused = (i == focused_index)
		draw_input(
			buf,
			{pos.x, current_y},
			field.state,
			width,
			.Box,
			field.label,
			munin.Basic_Color.BrightYellow,
			munin.Basic_Color.White,
			munin.Basic_Color.BrightGreen,
			munin.Basic_Color.BrightBlue,
		)
		current_y += 4 // Box takes 3 lines + spacing
	}
}
