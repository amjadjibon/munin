package components

import munin ".."
import "core:strings"

// ============================================================
// TABLE COMPONENT
// ============================================================

Table_Align :: enum {
	Left,
	Center,
	Right,
}

Table_Column :: struct {
	title: string,
	width: int,
	align: Table_Align,
}

// Draw a simple table
draw_table :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	columns: []Table_Column,
	rows: [][]string,
	header_color: munin.Color = munin.Basic_Color.BrightCyan,
	border_color: munin.Color = munin.Basic_Color.White,
) {
	if len(columns) == 0 {
		return
	}

	current_y := pos.y

	// Calculate total width
	total_width := 1 // Start with left border
	for col in columns {
		total_width += col.width + 1 // column width + right border
	}

	// Draw top border
	munin.move_cursor(buf, {pos.x, current_y})
	munin.set_color(buf, border_color)
	strings.write_string(buf, "┌")
	for col, i in columns {
		for j in 0 ..< col.width {
			strings.write_string(buf, "─")
		}
		if i < len(columns) - 1 {
			strings.write_string(buf, "┬")
		}
	}
	strings.write_string(buf, "┐")
	munin.reset_style(buf)
	current_y += 1

	// Draw header
	munin.move_cursor(buf, {pos.x, current_y})
	munin.set_color(buf, border_color)
	strings.write_string(buf, "│")
	for col in columns {
		munin.reset_style(buf)
		munin.set_bold(buf)
		munin.set_color(buf, header_color)
		padded := pad_string(col.title, col.width, col.align)
		strings.write_string(buf, padded)
		munin.reset_style(buf)
		munin.set_color(buf, border_color)
		strings.write_string(buf, "│")
	}
	munin.reset_style(buf)
	current_y += 1

	// Draw header separator
	munin.move_cursor(buf, {pos.x, current_y})
	munin.set_color(buf, border_color)
	strings.write_string(buf, "├")
	for col, i in columns {
		for j in 0 ..< col.width {
			strings.write_string(buf, "─")
		}
		if i < len(columns) - 1 {
			strings.write_string(buf, "┼")
		}
	}
	strings.write_string(buf, "┤")
	munin.reset_style(buf)
	current_y += 1

	// Draw rows
	for row in rows {
		munin.move_cursor(buf, {pos.x, current_y})
		munin.set_color(buf, border_color)
		strings.write_string(buf, "│")
		for col, i in columns {
			munin.reset_style(buf)
			cell := i < len(row) ? row[i] : ""
			padded := pad_string(cell, col.width, col.align)
			strings.write_string(buf, padded)
			munin.set_color(buf, border_color)
			strings.write_string(buf, "│")
		}
		munin.reset_style(buf)
		current_y += 1
	}

	// Draw bottom border
	munin.move_cursor(buf, {pos.x, current_y})
	munin.set_color(buf, border_color)
	strings.write_string(buf, "└")
	for col, i in columns {
		for j in 0 ..< col.width {
			strings.write_string(buf, "─")
		}
		if i < len(columns) - 1 {
			strings.write_string(buf, "┴")
		}
	}
	strings.write_string(buf, "┘")
	munin.reset_style(buf)
}

// Helper to pad string based on alignment
// Uses temp_allocator to avoid memory leaks
@(private)
pad_string :: proc(s: string, width: int, align: Table_Align) -> string {
	visual_width := munin.get_visible_width(s)
	if visual_width >= width {
		// Truncate if too long - need to be careful with UTF-8
		return s[:min(len(s), width)]
	}

	padding := width - visual_width
	switch align {
	case .Left:
		return strings.concatenate(
			{s, strings.repeat(" ", padding, context.temp_allocator)},
			context.temp_allocator,
		)
	case .Right:
		return strings.concatenate(
			{strings.repeat(" ", padding, context.temp_allocator), s},
			context.temp_allocator,
		)
	case .Center:
		left := padding / 2
		right := padding - left
		return strings.concatenate(
			{
				strings.repeat(" ", left, context.temp_allocator),
				s,
				strings.repeat(" ", right, context.temp_allocator),
			},
			context.temp_allocator,
		)
	}
	return s
}
