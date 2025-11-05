package munin

import "core:fmt"
import "core:strings"
import "core:unicode/utf8"

// ============================================================
// TYPES
// ============================================================

// 2D integer vector type for positions
Vec2i :: [2]int

// ============================================================
// RENDERING UTILITIES
// ============================================================

// Clear screen and reset cursor to home position
clear_screen :: proc(buf: ^strings.Builder) {
	// Use more efficient method: home cursor + clear from cursor to end
	// This reduces flickering compared to \x1b[2J
	strings.write_string(buf, "\x1b[H\x1b[J")
}

move_cursor :: proc(buf: ^strings.Builder, pos: Vec2i) {
	assert(buf != nil, "Buffer cannot be nil")
	assert(pos.x >= 0 && pos.y >= 0, "Position coordinates must be non-negative")
	fmt.sbprintf(buf, "\x1b[%d;%dH", pos.y, pos.x)
}

hide_cursor :: proc(buf: ^strings.Builder) {
	strings.write_string(buf, "\x1b[?25l")
}

show_cursor :: proc(buf: ^strings.Builder) {
	strings.write_string(buf, "\x1b[?25h")
}

set_color :: proc(buf: ^strings.Builder, color: Color) {
	strings.write_string(buf, ANSI_FG_CODES[color])
}

set_bg_color :: proc(buf: ^strings.Builder, color: Color) {
	strings.write_string(buf, ANSI_BG_CODES[color])
}

set_bold :: proc(buf: ^strings.Builder) {
	strings.write_string(buf, "\x1b[1m")
}

set_dim :: proc(buf: ^strings.Builder) {
	strings.write_string(buf, "\x1b[2m")
}

set_underline :: proc(buf: ^strings.Builder) {
	strings.write_string(buf, "\x1b[4m")
}

set_blink :: proc(buf: ^strings.Builder) {
	strings.write_string(buf, "\x1b[5m")
}

set_reverse :: proc(buf: ^strings.Builder) {
	strings.write_string(buf, "\x1b[7m")
}

reset_style :: proc(buf: ^strings.Builder) {
	strings.write_string(buf, "\x1b[0m")
}

// Draw a box (optimized to reduce cursor movements)
draw_box :: proc(buf: ^strings.Builder, pos: Vec2i, width, height: int, color: Color = .Reset) {
	assert(buf != nil, "Buffer cannot be nil")
	assert(pos.x >= 0 && pos.y >= 0, "Position coordinates must be non-negative")
	assert(width >= 2 && height >= 2, "Box dimensions must be at least 2x2")

	if color != .Reset {
		set_color(buf, color)
	}

	// Top border
	move_cursor(buf, pos)
	strings.write_string(buf, "┌")
	for i in 0 ..< width - 2 {
		strings.write_string(buf, "─")
	}
	strings.write_string(buf, "┐")

	// Middle rows
	for i in 1 ..< height - 1 {
		move_cursor(buf, {pos.x, pos.y + i})
		strings.write_string(buf, "│")
		for j in 0 ..< width - 2 {
			strings.write_byte(buf, ' ')
		}
		strings.write_string(buf, "│")
	}

	// Bottom border
	move_cursor(buf, {pos.x, pos.y + height - 1})
	strings.write_string(buf, "└")
	for i in 0 ..< width - 2 {
		strings.write_string(buf, "─")
	}
	strings.write_string(buf, "┘")

	if color != .Reset {
		reset_style(buf)
	}
}

// Print text at position with optional color
print_at :: proc(buf: ^strings.Builder, pos: Vec2i, text: string, color: Color = .Reset) {
	assert(buf != nil, "Buffer cannot be nil")
	assert(pos.x >= 0 && pos.y >= 0, "Position coordinates must be non-negative")

	move_cursor(buf, pos)
	if color != .Reset {
		set_color(buf, color)
	}
	strings.write_string(buf, text)
	if color != .Reset {
		reset_style(buf)
	}
}

// Print formatted text at position with optional color
printf_at :: proc(buf: ^strings.Builder, pos: Vec2i, color: Color, format: string, args: ..any) {
	assert(buf != nil, "Buffer cannot be nil")
	assert(pos.x >= 0 && pos.y >= 0, "Position coordinates must be non-negative")

	move_cursor(buf, pos)
	if color != .Reset {
		set_color(buf, color)
	}
	fmt.sbprintf(buf, format, ..args)
	if color != .Reset {
		reset_style(buf)
	}
}

// Draw a centered title with optional styling
draw_title :: proc(
	buf: ^strings.Builder,
	pos: Vec2i,
	width: int,
	title: string,
	color: Color = .Reset,
	bold := false,
) {
	assert(buf != nil, "Buffer cannot be nil")
	assert(pos.x >= 0 && pos.y >= 0, "Position coordinates must be non-negative")
	assert(width > 0, "Width must be positive")

	// Calculate centered position using rune count for proper UTF-8 support
	title_len := utf8.rune_count_in_string(title)
	padding := (width - title_len) / 2

	// Ensure padding is non-negative
	if padding < 0 {
		padding = 0
	}

	centered_x := pos.x + padding

	// Draw title
	move_cursor(buf, {centered_x, pos.y})
	if bold {
		set_bold(buf)
	}
	if color != .Reset {
		set_color(buf, color)
	}
	strings.write_string(buf, title)
	if color != .Reset || bold {
		reset_style(buf)
	}
}

// ============================================================
// WINDOW UTILITIES
// ============================================================

// Set the terminal window title using ANSI escape sequence
// Note: This must be called from the render buffer to take effect
set_window_title :: proc(buf: ^strings.Builder, title: string) {
	// OSC 0 ; title BEL
	// \x1b]0; sets the window title, \x07 is BEL (bell/terminator)
	fmt.sbprintf(buf, "\x1b]0;%s\x07", title)
}
