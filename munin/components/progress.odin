package components

import munin ".."
import "core:strings"

// ============================================================
// PROGRESS BAR COMPONENT
// ============================================================

Progress_Style :: enum {
	Blocks, // ████░░░░
	Bars, // ||||
	Dots, // ●●●○○○○
	Arrow, // ====>---
	Gradient, // ▓▓▒▒░░░
}

// Draw a horizontal progress bar
draw_progress_bar :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	width: int,
	progress: int, // 0-100
	style: Progress_Style = .Blocks,
	filled_color: munin.Color = munin.Basic_Color.BrightGreen,
	empty_color: munin.Color = munin.Basic_Color.White,
	show_percent: bool = true,
) {
	filled := (progress * width) / 100
	filled = clamp(filled, 0, width)

	munin.move_cursor(buf, pos)

	// Draw filled portion
	munin.set_color(buf, filled_color)
	switch style {
	case .Blocks:
		for i in 0 ..< filled {
			strings.write_string(buf, "█")
		}
	case .Bars:
		for i in 0 ..< filled {
			strings.write_string(buf, "|")
		}
	case .Dots:
		for i in 0 ..< filled {
			strings.write_string(buf, "●")
		}
	case .Arrow:
		for i in 0 ..< filled - 1 {
			strings.write_string(buf, "=")
		}
		if filled > 0 {
			strings.write_string(buf, ">")
		}
	case .Gradient:
		for i in 0 ..< filled {
			strings.write_string(buf, "▓")
		}
	}

	// Draw empty portion
	munin.set_color(buf, empty_color)
	switch style {
	case .Blocks:
		for i in filled ..< width {
			strings.write_string(buf, "░")
		}
	case .Bars:
		for i in filled ..< width {
			strings.write_string(buf, " ")
		}
	case .Dots:
		for i in filled ..< width {
			strings.write_string(buf, "○")
		}
	case .Arrow:
		for i in filled ..< width {
			strings.write_string(buf, "-")
		}
	case .Gradient:
		for i in filled ..< width {
			strings.write_string(buf, "░")
		}
	}
	munin.reset_style(buf)

	// Show percentage
	if show_percent {
		munin.move_cursor(buf, {pos.x + width + 2, pos.y})
		munin.printf_at(buf, {pos.x + width + 2, pos.y}, filled_color, "%3d%%", progress)
	}
}

// Draw a vertical progress bar
draw_progress_bar_vertical :: proc(
	buf: ^strings.Builder,
	x, y, height: int,
	progress: int, // 0-100
	filled_color: munin.Color = munin.Basic_Color.BrightGreen,
	empty_color: munin.Color = munin.Basic_Color.White,
) {
	filled := (progress * height) / 100
	filled = clamp(filled, 0, height)

	// Draw from bottom to top
	for i in 0 ..< height {
		munin.move_cursor(buf, {x, y + (height - 1 - i)})
		if i < filled {
			munin.set_color(buf, filled_color)
			strings.write_string(buf, "█")
		} else {
			munin.set_color(buf, empty_color)
			strings.write_string(buf, "░")
		}
	}
	munin.reset_style(buf)
}

// Draw a progress bar with border
draw_progress_bar_boxed :: proc(
	buf: ^strings.Builder,
	x, y, width: int,
	progress: int,
	label: string = "",
	filled_color: munin.Color = munin.Basic_Color.BrightGreen,
	empty_color: munin.Color = munin.Basic_Color.White,
) {
	current_y := y

	// Draw label if provided
	if len(label) > 0 {
		munin.print_at(buf, {x, current_y}, label, munin.Basic_Color.BrightYellow)
		current_y += 1
	}

	// Draw border
	munin.move_cursor(buf, {x, current_y})
	strings.write_string(buf, "[")
	munin.move_cursor(buf, {x + width + 1, current_y})
	strings.write_string(buf, "]")

	// Draw progress inside border
	draw_progress_bar(
		buf,
		{x + 1, current_y},
		width - 1,
		progress,
		.Blocks,
		filled_color,
		empty_color,
		true,
	)
}
