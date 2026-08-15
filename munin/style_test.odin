package munin

import "core:strings"
import "core:testing"

// ============================================================
// STYLE TESTS - box model, borders, colors, fluent API
// ============================================================

// Helper: visible (ANSI-stripped) lines of a rendered style, with the
// trailing empty line dropped.
@(private = "file")
render_lines :: proc(s: Style, text: string) -> []string {
	out := style_render(s, text)
	defer delete(out)

	stripped := strip_ansi(out)
	lines := strings.split(stripped, "\n", context.temp_allocator)
	if len(lines) > 0 && lines[len(lines) - 1] == "" {
		return lines[:len(lines) - 1]
	}
	return lines
}

// ============================================================
// FLUENT API
// ============================================================

@(test)
test_new_style_is_empty :: proc(t: ^testing.T) {
	s := new_style()
	testing.expect(t, s.foreground == nil, "No foreground by default")
	testing.expect(t, s.background == nil, "No background by default")
	testing.expect(t, s.border == nil, "No border by default")
	testing.expect_value(t, s.bold, false)
	testing.expect_value(t, s.padding, [4]int{0, 0, 0, 0})
	testing.expect_value(t, s.margin, [4]int{0, 0, 0, 0})
}

@(test)
test_style_fluent_api_does_not_mutate_source :: proc(t: ^testing.T) {
	base := new_style()
	bold := style_bold(base)

	testing.expect_value(t, bold.bold, true)
	testing.expect_value(t, base.bold, false)
}

@(test)
test_style_attributes :: proc(t: ^testing.T) {
	s := new_style()
	s = style_bold(s)
	s = style_italic(s)
	s = style_underline(s)

	testing.expect_value(t, s.bold, true)
	testing.expect_value(t, s.italic, true)
	testing.expect_value(t, s.underline, true)

	s = style_bold(s, false)
	testing.expect_value(t, s.bold, false)
}

@(test)
test_style_padding_helpers :: proc(t: ^testing.T) {
	testing.expect_value(t, style_padding_all(new_style(), 2).padding, [4]int{2, 2, 2, 2})
	testing.expect_value(t, style_padding_v_h(new_style(), 1, 3).padding, [4]int{1, 3, 1, 3})
	testing.expect_value(t, style_padding(new_style(), 1, 2, 3, 4).padding, [4]int{1, 2, 3, 4})
}

@(test)
test_style_margin_helpers :: proc(t: ^testing.T) {
	testing.expect_value(t, style_margin_all(new_style(), 2).margin, [4]int{2, 2, 2, 2})
	testing.expect_value(t, style_margin(new_style(), 1, 2, 3, 4).margin, [4]int{1, 2, 3, 4})
}

@(test)
test_style_color_from_string :: proc(t: ^testing.T) {
	s := style_foreground_str(new_style(), "red")
	fg, ok := s.foreground.?
	testing.expect(t, ok, "Foreground should be set")
	testing.expect_value(t, fg, Color(Basic_Color.Red))

	bg, bg_ok := style_background_str(new_style(), "#ff0000").background.?
	testing.expect(t, bg_ok, "Background should be set")
	testing.expect_value(t, bg, Color(RGB{255, 0, 0}))
}

@(test)
test_style_color_from_invalid_string_is_ignored :: proc(t: ^testing.T) {
	s := style_foreground_str(new_style(), "not-a-color")
	testing.expect(t, s.foreground == nil, "Invalid color should leave the style untouched")
}

// ============================================================
// RENDERING - BOX MODEL
// ============================================================

@(test)
test_style_render_plain_text :: proc(t: ^testing.T) {
	lines := render_lines(new_style(), "hi")
	testing.expect_value(t, len(lines), 1)
	testing.expect_value(t, lines[0], "hi")
}

@(test)
test_style_render_pads_to_fixed_width :: proc(t: ^testing.T) {
	lines := render_lines(style_width(new_style(), 5), "hi")
	testing.expect_value(t, len(lines), 1)
	testing.expect_value(t, lines[0], "hi   ")
}

@(test)
test_style_render_width_smaller_than_content_is_ignored :: proc(t: ^testing.T) {
	lines := render_lines(style_width(new_style(), 1), "hello")
	testing.expect_value(t, lines[0], "hello")
}

@(test)
test_style_render_pads_ragged_lines_to_same_width :: proc(t: ^testing.T) {
	lines := render_lines(new_style(), "a\nbbb")
	testing.expect_value(t, len(lines), 2)
	testing.expect_value(t, get_visible_width(lines[0]), get_visible_width(lines[1]))
}

@(test)
test_style_render_padding :: proc(t: ^testing.T) {
	lines := render_lines(style_padding_all(new_style(), 1), "hi")
	// One blank padding row above and below, content indented by one space.
	testing.expect_value(t, len(lines), 3)
	testing.expect_value(t, lines[0], "    ")
	testing.expect_value(t, lines[1], " hi ")
	testing.expect_value(t, lines[2], "    ")
}

@(test)
test_style_render_margin :: proc(t: ^testing.T) {
	lines := render_lines(style_margin(new_style(), 1, 0, 1, 2), "hi")
	testing.expect_value(t, len(lines), 3)
	testing.expect_value(t, lines[0], "")
	testing.expect_value(t, lines[1], "  hi")
	testing.expect_value(t, lines[2], "")
}

@(test)
test_style_render_border :: proc(t: ^testing.T) {
	lines := render_lines(style_border(new_style(), Border_Normal), "hi")
	testing.expect_value(t, len(lines), 3)
	testing.expect_value(t, lines[0], "┌──┐")
	testing.expect_value(t, lines[1], "│hi│")
	testing.expect_value(t, lines[2], "└──┘")
}

@(test)
test_style_render_border_with_padding :: proc(t: ^testing.T) {
	s := style_border(style_padding_v_h(new_style(), 0, 1), Border_Normal)
	lines := render_lines(s, "hi")
	testing.expect_value(t, len(lines), 3)
	testing.expect_value(t, lines[0], "┌────┐")
	testing.expect_value(t, lines[1], "│ hi │")
	testing.expect_value(t, lines[2], "└────┘")
}

@(test)
test_style_render_border_rows_have_equal_width :: proc(t: ^testing.T) {
	s := style_border(style_padding_all(style_width(new_style(), 10), 1), Border_Double)
	lines := render_lines(s, "a\nlonger line")

	testing.expect(t, len(lines) > 2, "Should render several rows")
	expected := get_visible_width(lines[0])
	for line, i in lines {
		testing.expectf(
			t,
			get_visible_width(line) == expected,
			"Row %d width %d, expected %d",
			i,
			get_visible_width(line),
			expected,
		)
	}
}

@(test)
test_style_render_wide_characters_align :: proc(t: ^testing.T) {
	// CJK characters are two cells wide; the border must still line up.
	lines := render_lines(style_border(new_style(), Border_Normal), "你好\nab")
	expected := get_visible_width(lines[0])
	for line, i in lines {
		testing.expectf(t, get_visible_width(line) == expected, "Row %d misaligned", i)
	}
}

// ============================================================
// RENDERING - ATTRIBUTES
// ============================================================

@(test)
test_style_render_emits_bold_and_color :: proc(t: ^testing.T) {
	s := style_bold(style_foreground(new_style(), Basic_Color.Red))
	out := style_render(s, "hi")
	defer delete(out)

	testing.expect(t, strings.contains(out, "\x1b[1m"), "Should emit bold")
	testing.expect(t, strings.contains(out, "\x1b[31m"), "Should emit red")
	testing.expect(t, strings.contains(out, "\x1b[0m"), "Should reset")
	testing.expect_value(t, strip_ansi(out), "hi\n")
}

@(test)
test_style_render_emits_rgb_color :: proc(t: ^testing.T) {
	s := style_foreground(new_style(), RGB{1, 2, 3})
	out := style_render(s, "x")
	defer delete(out)

	testing.expect(t, strings.contains(out, "\x1b[38;2;1;2;3m"), "Should emit truecolor")
}

@(test)
test_style_render_emits_background :: proc(t: ^testing.T) {
	s := style_background(new_style(), ANSI256(42))
	out := style_render(s, "x")
	defer delete(out)

	testing.expect(t, strings.contains(out, "\x1b[48;5;42m"), "Should emit 256-color background")
}

@(test)
test_style_render_border_color :: proc(t: ^testing.T) {
	s := style_border_foreground(style_border(new_style(), Border_Normal), Basic_Color.BrightCyan)
	out := style_render(s, "x")
	defer delete(out)

	testing.expect(t, strings.contains(out, "\x1b[96m"), "Should emit border color")
}

@(test)
test_style_border_foreground_str :: proc(t: ^testing.T) {
	s := style_border_foreground_str(new_style(), "cyan")
	fg, ok := s.border_fg.?
	testing.expect(t, ok, "Border foreground should be set")
	testing.expect_value(t, fg, Color(Basic_Color.Cyan))
}

// ============================================================
// EDGE CASES
// ============================================================

@(test)
test_style_render_empty_text :: proc(t: ^testing.T) {
	out := style_render(new_style(), "")
	defer delete(out)
	testing.expect_value(t, strip_ansi(out), "\n")
}

@(test)
test_style_render_text_with_existing_ansi :: proc(t: ^testing.T) {
	// Pre-colored content must not count its escape bytes towards width.
	s := style_border(new_style(), Border_Normal)
	lines := render_lines(s, "\x1b[31mred\x1b[0m")
	testing.expect_value(t, get_visible_width(lines[0]), 5) // 3 content + 2 border
}

@(test)
test_style_render_result_is_independent_copy :: proc(t: ^testing.T) {
	a := style_render(new_style(), "first")
	defer delete(a)
	b := style_render(new_style(), "second")
	defer delete(b)

	testing.expect_value(t, strip_ansi(a), "first\n")
	testing.expect_value(t, strip_ansi(b), "second\n")
}

@(test)
test_has_border :: proc(t: ^testing.T) {
	testing.expect(t, has_border(Border_Normal), "Normal border is set")
	testing.expect(t, has_border(Border_Hidden), "Hidden border still has characters")
	testing.expect(t, !has_border(Border{}), "Zero border is not set")
}
