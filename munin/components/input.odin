package components

import munin ".."
import "core:strings"
import "core:unicode/utf8"

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
	// Convert rune to UTF-8
	buf: [4]u8
	n := utf8_encode_rune(buf[:], char)
	if len(state.buffer) + n > state.max_length {
		return
	}

	state.cursor_pos = utf8_boundary_at_or_before(state.buffer[:], state.cursor_pos)

	// Insert at cursor position
	for i in 0 ..< n {
		inject_at(&state.buffer, state.cursor_pos, buf[i])
		state.cursor_pos += 1
	}
}

// Remove character before cursor (backspace)
// Properly handles multi-byte UTF-8 characters
input_backspace :: proc(state: ^Input_State) {
	if state.cursor_pos > 0 && len(state.buffer) > 0 {
		state.cursor_pos = clamp(state.cursor_pos, 0, len(state.buffer))
		char_start := utf8_prev_boundary(state.buffer[:], state.cursor_pos)
		char_len := utf8_char_len_at(state.buffer[:], char_start)

		// Remove all bytes of this character
		for _ in 0 ..< char_len {
			ordered_remove(&state.buffer, char_start)
		}
		state.cursor_pos = char_start
	}
}

// Remove character at cursor (delete)
// Properly handles multi-byte UTF-8 characters
input_delete :: proc(state: ^Input_State) {
	if state.cursor_pos < len(state.buffer) {
		state.cursor_pos = clamp(state.cursor_pos, 0, len(state.buffer))
		state.cursor_pos = utf8_boundary_at_or_before(state.buffer[:], state.cursor_pos)

		// Determine the length of the UTF-8 character at cursor
		char_len := utf8_char_len_at(state.buffer[:], state.cursor_pos)

		// Remove all bytes of this character
		for _ in 0 ..< char_len {
			if state.cursor_pos < len(state.buffer) {
				ordered_remove(&state.buffer, state.cursor_pos)
			}
		}
	}
}

// Move cursor left
input_cursor_left :: proc(state: ^Input_State) {
	state.cursor_pos = utf8_prev_boundary(state.buffer[:], state.cursor_pos)
}

// Move cursor right
input_cursor_right :: proc(state: ^Input_State) {
	state.cursor_pos = utf8_next_boundary(state.buffer[:], state.cursor_pos)
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

// Get current input text.
//
// The result is a *view* into the input's own buffer, not a copy: it stays
// valid only until the next edit. input_clear(), input_add_char(),
// input_backspace() and friends rewrite those same bytes, so a string kept
// across an edit silently changes content (and a growing buffer may move it
// entirely). Use input_clone_text() for anything you intend to store.
input_get_text :: proc(state: ^Input_State) -> string {
	return string(state.buffer[:])
}

// Get a copy of the current input text, owned by the caller.
// Use this whenever the text outlives the next edit - storing it in a model,
// pushing it into a history, returning it from a form.
input_clone_text :: proc(state: ^Input_State, allocator := context.allocator) -> string {
	return strings.clone(string(state.buffer[:]), allocator)
}

// Clear input
input_clear :: proc(state: ^Input_State) {
	clear(&state.buffer)
	state.cursor_pos = 0
}

@(private)
utf8_is_continuation :: proc(b: u8) -> bool {
	return (b & 0xC0) == 0x80
}

@(private)
utf8_len_from_first_byte :: proc(first: u8) -> int {
	if first < 0x80 {
		return 1
	}
	if first >= 0xC2 && first <= 0xDF {
		return 2
	}
	if first >= 0xE0 && first <= 0xEF {
		return 3
	}
	if first >= 0xF0 && first <= 0xF4 {
		return 4
	}
	return 1
}

@(private)
utf8_char_len_at :: proc(buffer: []u8, pos: int) -> int {
	if pos < 0 || pos >= len(buffer) {
		return 0
	}
	char_len := utf8_len_from_first_byte(buffer[pos])
	if pos + char_len > len(buffer) {
		return 1
	}
	for i in 1 ..< char_len {
		if !utf8_is_continuation(buffer[pos + i]) {
			return 1
		}
	}
	return char_len
}

@(private)
utf8_prev_boundary :: proc(buffer: []u8, pos: int) -> int {
	p := clamp(pos, 0, len(buffer))
	if p <= 0 {
		return 0
	}
	p -= 1
	for p > 0 && utf8_is_continuation(buffer[p]) {
		p -= 1
	}
	return p
}

@(private)
utf8_boundary_at_or_before :: proc(buffer: []u8, pos: int) -> int {
	p := clamp(pos, 0, len(buffer))
	if p >= len(buffer) {
		return len(buffer)
	}
	for p > 0 && utf8_is_continuation(buffer[p]) {
		p -= 1
	}
	return p
}

@(private)
utf8_next_boundary :: proc(buffer: []u8, pos: int) -> int {
	if len(buffer) == 0 {
		return 0
	}

	p := clamp(pos, 0, len(buffer))
	if p >= len(buffer) {
		return len(buffer)
	}
	for p > 0 && utf8_is_continuation(buffer[p]) {
		p -= 1
	}

	char_len := utf8_char_len_at(buffer, p)
	return min(p + char_len, len(buffer))
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
	sanitize: bool = true,
) {
	// Nothing sensible to draw, and the box style would place its right
	// border at x-1 and trip move_cursor's non-negative assert.
	if width <= 0 || (style == .Box && width < 2) {
		return
	}

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
			sanitize,
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
			sanitize,
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
			sanitize,
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
	sanitize: bool,
) {
	// A caller passing a small width (draw_input subtracts 2 for the box
	// borders) must not produce a negative slice bound below.
	if width <= 0 {
		return
	}

	munin.move_cursor(buf, pos)

	// Show placeholder if empty
	if len(state.buffer) == 0 {
		munin.set_color(buf, placeholder_color)
		// Truncate on character boundaries, not byte offsets: slicing at a
		// raw byte index splits multi-byte characters and emits broken UTF-8.
		placeholder_text := truncate_visible_width(display_text(state.placeholder, sanitize), width)

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
	text := display_text(input_get_text(state), sanitize)
	shown := text
	if state.is_password {
		// Mask password. One asterisk per character, not per byte, and
		// allocated in the temp arena - this runs every frame, and the old
		// context.allocator version was never freed.
		rune_count := utf8.rune_count_in_string(text)
		shown = strings.repeat("*", rune_count, context.temp_allocator)
	}

	// Truncate if too long (on character boundaries)
	shown = truncate_visible_width(shown, width)

	munin.set_color(buf, text_color)

	// Draw text with cursor.
	// Iterate by rune so the cursor block replaces a whole character rather
	// than a single byte of one.
	byte_pos := 0
	for byte_pos < len(shown) {
		r, size := utf8.decode_rune_in_string(shown[byte_pos:])
		if size == 0 {
			break
		}

		if byte_pos == state.cursor_pos && state.is_focused {
			if state.cursor_blink_state {
				// Show cursor block
				munin.set_color(buf, cursor_color)
				strings.write_string(buf, "█")
			} else {
				// Show actual character when cursor is "off"
				munin.set_color(buf, text_color)
				strings.write_rune(buf, r)
			}
		} else {
			strings.write_rune(buf, r)
		}

		byte_pos += size
	}

	// Draw cursor at end if needed
	if state.cursor_pos >= len(shown) && state.is_focused {
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
