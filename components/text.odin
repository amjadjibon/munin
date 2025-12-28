package components

import munin "../munin"
import "core:strings"

// ============================================================
// TEXT COMPONENTS
// ============================================================

// Draw text with word wrapping
draw_text_wrapped :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	max_width: int,
	text: string,
	color: munin.Color = munin.Basic_Color.White,
) -> int {
	words := strings.split(text, " ")
	defer delete(words)

	current_x := pos.x
	current_y := pos.y
	line_start_x := pos.x

	munin.set_color(buf, color)

	for word in words {
		word_len := len(word)

		// Check if word fits on current line
		if current_x + word_len > pos.x + max_width && current_x != line_start_x {
			// Move to next line
			current_y += 1
			current_x = line_start_x
		}

		// Draw word
		munin.move_cursor(buf, {current_x, current_y})
		strings.write_string(buf, word)
		current_x += word_len + 1 // +1 for space
	}

	munin.reset_style(buf)
	return current_y - pos.y + 1 // Return number of lines used
}

// Draw a heading with underline
draw_heading :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	text: string,
	level: int = 1,
	color: munin.Color = munin.Basic_Color.BrightCyan,
) {
	munin.set_bold(buf)
	munin.print_at(buf, {pos.x, pos.y}, text, color)
	munin.reset_style(buf)

	// Draw underline for level 1 headings
	if level == 1 {
		munin.move_cursor(buf, {pos.x, pos.y + 1})
		munin.set_color(buf, color)
		for i in 0 ..< len(text) {
			strings.write_string(buf, "═")
		}
		munin.reset_style(buf)
	}
}

// Draw centered text
draw_text_centered :: proc(
	buf: ^strings.Builder,
	y, screen_width: int,
	text: string,
	color: munin.Color = .White,
) {
	x := (screen_width - len(text)) / 2
	munin.print_at(buf, {x, y}, text, color)
}

// Draw a banner with padding
draw_banner :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	width: int,
	text: string,
	bg_color: munin.Color = munin.Basic_Color.BrightBlue,
	text_color: munin.Color = munin.Basic_Color.White,
) {
	// Calculate centered position
	padding := (width - len(text)) / 2

	munin.move_cursor(buf, pos)
	munin.set_bg_color(buf, bg_color)
	munin.set_color(buf, text_color)
	munin.set_bold(buf)

	// Draw with padding
	for i in 0 ..< padding {
		strings.write_byte(buf, ' ')
	}
	strings.write_string(buf, text)
	for i in 0 ..< width - padding - len(text) {
		strings.write_byte(buf, ' ')
	}

	munin.reset_style(buf)
}

// Draw a label-value pair
draw_label_value :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	label, value: string,
	label_color: munin.Color = munin.Basic_Color.BrightYellow,
	value_color: munin.Color = munin.Basic_Color.White,
	separator: string = ": ",
) {
	munin.print_at(buf, pos, label, label_color)
	munin.print_at(buf, {pos.x + len(label), pos.y}, separator, munin.Basic_Color.BrightBlue)
	munin.print_at(buf, {pos.x + len(label) + len(separator), pos.y}, value, value_color)
}
