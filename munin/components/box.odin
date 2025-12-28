package components

import munin ".."
import "core:strings"

// ============================================================
// BOX COMPONENT
// ============================================================

Box_Style :: enum {
	Single,
	Double,
	Rounded,
	Bold,
	Ascii,
}

Box_Border :: struct {
	top_left:     string,
	top_right:    string,
	bottom_left:  string,
	bottom_right: string,
	horizontal:   string,
	vertical:     string,
}

BOX_STYLES := [Box_Style]Box_Border {
	.Single = {
		top_left = "┌",
		top_right = "┐",
		bottom_left = "└",
		bottom_right = "┘",
		horizontal = "─",
		vertical = "│",
	},
	.Double = {
		top_left = "╔",
		top_right = "╗",
		bottom_left = "╚",
		bottom_right = "╝",
		horizontal = "═",
		vertical = "║",
	},
	.Rounded = {
		top_left = "╭",
		top_right = "╮",
		bottom_left = "╰",
		bottom_right = "╯",
		horizontal = "─",
		vertical = "│",
	},
	.Bold = {
		top_left = "┏",
		top_right = "┓",
		bottom_left = "┗",
		bottom_right = "┛",
		horizontal = "━",
		vertical = "┃",
	},
	.Ascii = {
		top_left = "+",
		top_right = "+",
		bottom_left = "+",
		bottom_right = "+",
		horizontal = "-",
		vertical = "|",
	},
}

// Draw a box with specified style
draw_box_styled :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	width, height: int,
	style: Box_Style = .Single,
	color: munin.Color = munin.Basic_Color.Reset,
) {
	border := BOX_STYLES[style]

	if !munin.is_color_reset(color) {
		munin.set_color(buf, color)
	}

	// Top border
	munin.move_cursor(buf, pos)
	strings.write_string(buf, border.top_left)
	for i in 0 ..< width - 2 {
		strings.write_string(buf, border.horizontal)
	}
	strings.write_string(buf, border.top_right)

	// Middle rows
	for i in 1 ..< height - 1 {
		munin.move_cursor(buf, {pos.x, pos.y + i})
		strings.write_string(buf, border.vertical)
		for j in 0 ..< width - 2 {
			strings.write_byte(buf, ' ')
		}
		strings.write_string(buf, border.vertical)
	}

	// Bottom border
	munin.move_cursor(buf, {pos.x, pos.y + height - 1})
	strings.write_string(buf, border.bottom_left)
	for i in 0 ..< width - 2 {
		strings.write_string(buf, border.horizontal)
	}
	strings.write_string(buf, border.bottom_right)

	if !munin.is_color_reset(color) {
		munin.reset_style(buf)
	}
}

// Draw a box with title
draw_box_titled :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	width, height: int,
	title: string,
	style: Box_Style = .Single,
	color: munin.Color = munin.Basic_Color.Reset,
	title_color: munin.Color = munin.Basic_Color.BrightWhite,
) {
	draw_box_styled(buf, pos, width, height, style, color)

	// Draw title in the top border
	if len(title) > 0 && width > 4 {
		title_x := pos.x + 2
		title_display := title
		if len(title) > width - 4 {
			title_display = title[:width - 4]
		}

		munin.move_cursor(buf, {title_x, pos.y})
		if !munin.is_color_reset(color) {
			munin.set_color(buf, color)
		}
		strings.write_string(buf, " ")
		munin.set_bold(buf)
		if !munin.is_color_reset(title_color) {
			munin.set_color(buf, title_color)
		}
		strings.write_string(buf, title_display)
		munin.reset_style(buf)
		if !munin.is_color_reset(color) {
			munin.set_color(buf, color)
		}
		strings.write_string(buf, " ")
		munin.reset_style(buf)
	}
}

// Draw a filled box with background color
draw_box_filled :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	width, height: int,
	bg_color: munin.Color,
	border_style: Box_Style = .Single,
	border_color: munin.Color = munin.Basic_Color.Reset,
) {
	// Fill background
	munin.set_bg_color(buf, bg_color)
	for row in pos.y ..< pos.y + height {
		munin.move_cursor(buf, {pos.x, row})
		for col in 0 ..< width {
			strings.write_byte(buf, ' ')
		}
	}
	munin.reset_style(buf)

	// Draw border on top
	draw_box_styled(buf, pos, width, height, border_style, border_color)
}
