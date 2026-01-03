package munin

import "core:fmt"
import "core:strings"

// Style defines the appearance and layout of a text block
Style :: struct {
	// Colors
	foreground: Maybe(Color),
	background: Maybe(Color),

	// Text attributes
	bold:       bool,
	dim:        bool,
	italic:     bool,
	underline:  bool,
	blink:      bool,
	reverse:    bool,

	// Box Model
	padding:    [4]int, // top, right, bottom, left
	margin:     [4]int, // top, right, bottom, left

	// Sizing
	width:      Maybe(int),
	height:     Maybe(int),
	align:      Align, // To be implemented, currently defaults to left

	// Border
	border:     Maybe(Border),
	border_fg:  Maybe(Color),
	border_bg:  Maybe(Color),
}

Align :: enum {
	Left,
	Center,
	Right,
}

// Factory to create a new empty style
new_style :: proc() -> Style {
	return Style{}
}

// ============================================================
// FLUENT API - COLORS & ATTRIBUTES
// ============================================================

style_foreground :: proc(s: Style, color: Color) -> Style {
	res := s
	res.foreground = color
	return res
}

style_background :: proc(s: Style, color: Color) -> Style {
	res := s
	res.background = color
	return res
}

style_bold :: proc(s: Style, val: bool = true) -> Style {
	res := s
	res.bold = val
	return res
}

style_italic :: proc(s: Style, val: bool = true) -> Style {
	res := s
	res.italic = val
	return res
}

style_underline :: proc(s: Style, val: bool = true) -> Style {
	res := s
	res.underline = val
	return res
}

// ============================================================
// FLUENT API - BOX MODEL
// ============================================================

style_padding :: proc(s: Style, top, right, bottom, left: int) -> Style {
	res := s
	res.padding = {top, right, bottom, left}
	return res
}

style_padding_all :: proc(s: Style, val: int) -> Style {
	return style_padding(s, val, val, val, val)
}

style_padding_v_h :: proc(s: Style, v, h: int) -> Style {
	return style_padding(s, v, h, v, h)
}

style_margin :: proc(s: Style, top, right, bottom, left: int) -> Style {
	res := s
	res.margin = {top, right, bottom, left}
	return res
}

style_margin_all :: proc(s: Style, val: int) -> Style {
	return style_margin(s, val, val, val, val)
}

style_width :: proc(s: Style, width: int) -> Style {
	res := s
	res.width = width
	return res
}

// ============================================================
// FLUENT API - BORDER
// ============================================================

style_border :: proc(s: Style, border: Border) -> Style {
	res := s
	res.border = border
	return res
}

style_border_foreground :: proc(s: Style, color: Color) -> Style {
	res := s
	res.border_fg = color
	return res
}

// ============================================================
// RENDERING
// ============================================================

// Renders the text with the applied style
style_render :: proc(s: Style, text: string) -> string {
	b := strings.builder_make()
	// Note: We don't defer destroy here because we return the string.
	// The caller owns the result string, builder buffer will be freed when builder is destroyed if we did clean up properly,
	// but in Odin `strings.to_string` returns a string slice of the builder's buffer.
	// So we usually rely on allocator or specific lifecycle.
	// For this specific 'render' function that returns a string, we might want to return a newly allocated string
	// or assume the builder leaks if not handled.
	// Better approach for `render`: return a string allocated with the context allocator.
	// For simplicity in this v1, we'll build and return the string.

	lines := strings.split(text, "\n")
	defer delete(lines)

	// Calculate content width (max line length using visual width for proper Unicode/ANSI support)
	content_width := 0
	for line in lines {
		visual_width := get_visible_width(line)
		if visual_width > content_width {
			content_width = visual_width
		}
	}

	// Override with fixed width if set and larger
	if w, ok := s.width.?; ok {
		if w > content_width {
			content_width = w
		}
	}

	// 1. Margins (Top)
	for i in 0 ..< s.margin[0] {
		strings.write_string(&b, "\n")
	}

	// Helper to write margin left
	write_margin_left :: proc(b: ^strings.Builder, s: Style) {
		for i in 0 ..< s.margin[3] {
			strings.write_byte(b, ' ')
		}
	}

	// 2. Border (Top)
	if border, ok := s.border.?; ok {
		write_margin_left(&b, s)
		// Set border color
		if fg, ok := s.border_fg.?; ok {
			write_ansi_color(&b, fg, false)
		}

		strings.write_string(&b, border.top_left)
		// Border width includes padding + content
		total_inner_width := content_width + s.padding[1] + s.padding[3]
		for i in 0 ..< total_inner_width {
			strings.write_string(&b, border.top)
		}
		strings.write_string(&b, border.top_right)
		write_ansi_color(&b, Basic_Color.Reset, false) // Reset after border
		strings.write_string(&b, "\n")
	}

	// 3. Padding (Top)
	for i in 0 ..< s.padding[0] {
		write_margin_left(&b, s)
		if border, ok := s.border.?; ok {
			if fg, ok := s.border_fg.?; ok {strings.write_string(&b, color_to_ansi(fg, false))}
			strings.write_string(&b, border.left)
			strings.write_string(&b, color_to_ansi(Basic_Color.Reset, false))
		}

		// Inner width padding
		total_inner_width := content_width + s.padding[1] + s.padding[3]
		for j in 0 ..< total_inner_width {
			strings.write_byte(&b, ' ')
		}

		if border, ok := s.border.?; ok {
			if fg, ok := s.border_fg.?; ok {strings.write_string(&b, color_to_ansi(fg, false))}
			strings.write_string(&b, border.right)
			strings.write_string(&b, color_to_ansi(Basic_Color.Reset, false))
		}
		strings.write_string(&b, "\n")
	}

	// 4. Content
	for line in lines {
		write_margin_left(&b, s)

		// Left Border
		if border, ok := s.border.?; ok {
			if fg, ok := s.border_fg.?; ok {write_ansi_color(&b, fg, false)}
			strings.write_string(&b, border.left)
			write_ansi_color(&b, Basic_Color.Reset, false)
		}

		// Left Padding
		for i in 0 ..< s.padding[3] {
			strings.write_byte(&b, ' ')
		}

		// Content Styling
		if s.bold {strings.write_string(&b, "\x1b[1m")}
		if s.dim {strings.write_string(&b, "\x1b[2m")}
		if s.italic {strings.write_string(&b, "\x1b[3m")}
		if s.underline {strings.write_string(&b, "\x1b[4m")}

		if fg, ok := s.foreground.?; ok {
			write_ansi_color(&b, fg, false)
		}
		if bg, ok := s.background.?; ok {
			write_ansi_color(&b, bg, true)
		}

		strings.write_string(&b, line)

		// Reset Content Styling
		write_ansi_color(&b, Basic_Color.Reset, false)
		// Note: We blindly reset everything. This assumes background was what we wanted to reset too.
		// A full robust implementation would restore previous state, but \x1b[0m is standard.

		// Fill remaining width if any (for fixed width or alignment)
		remaining := content_width - get_visible_width(line)
		for i in 0 ..< remaining {
			strings.write_byte(&b, ' ')
		}

		// Right Padding
		for i in 0 ..< s.padding[1] {
			strings.write_byte(&b, ' ')
		}

		// Right Border
		if border, ok := s.border.?; ok {
			if fg, ok := s.border_fg.?; ok {write_ansi_color(&b, fg, false)}
			strings.write_string(&b, border.right)
			write_ansi_color(&b, Basic_Color.Reset, false)
		}

		strings.write_string(&b, "\n")
	}

	// 5. Padding (Bottom)
	for i in 0 ..< s.padding[2] {
		write_margin_left(&b, s)
		if border, ok := s.border.?; ok {
			if fg, ok := s.border_fg.?; ok {write_ansi_color(&b, fg, false)}
			strings.write_string(&b, border.left)
			write_ansi_color(&b, Basic_Color.Reset, false)
		}

		total_inner_width := content_width + s.padding[1] + s.padding[3]
		for j in 0 ..< total_inner_width {
			strings.write_byte(&b, ' ')
		}

		if border, ok := s.border.?; ok {
			if fg, ok := s.border_fg.?; ok {write_ansi_color(&b, fg, false)}
			strings.write_string(&b, border.right)
			write_ansi_color(&b, Basic_Color.Reset, false)
		}
		strings.write_string(&b, "\n")
	}

	// 6. Border (Bottom)
	if border, ok := s.border.?; ok {
		write_margin_left(&b, s)
		if fg, ok := s.border_fg.?; ok {write_ansi_color(&b, fg, false)}

		strings.write_string(&b, border.bottom_left)
		total_inner_width := content_width + s.padding[1] + s.padding[3]
		for i in 0 ..< total_inner_width {
			strings.write_string(&b, border.bottom)
		}
		strings.write_string(&b, border.bottom_right)
		write_ansi_color(&b, Basic_Color.Reset, false)
		strings.write_string(&b, "\n")
	}

	// 7. Margins (Bottom)
	for i in 0 ..< s.margin[2] {
		strings.write_string(&b, "\n")
	}

	res := strings.clone(strings.to_string(b))
	strings.builder_destroy(&b)
	return res
}

// ============================================================
// FLUENT API - COLOR STRINGS
// ============================================================

style_foreground_str :: proc(s: Style, str: string) -> Style {
	if c, ok := color_from_string(str).?; ok {
		return style_foreground(s, c)
	}
	return s
}

style_background_str :: proc(s: Style, str: string) -> Style {
	if c, ok := color_from_string(str).?; ok {
		return style_background(s, c)
	}
	return s
}

style_border_foreground_str :: proc(s: Style, str: string) -> Style {
	if c, ok := color_from_string(str).?; ok {
		return style_border_foreground(s, c)
	}
	return s
}
