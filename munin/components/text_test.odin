package components

import munin ".."
import "core:strings"
import "core:testing"

// ============================================================
// TEXT COMPONENTS
// ============================================================

@(test)
test_draw_text_wrapped_single_line :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	lines := draw_text_wrapped(&buf, {0, 0}, 40, "short enough")
	testing.expect_value(t, lines, 1)
	testing.expect(
		t,
		strings.contains(munin.strip_ansi(strings.to_string(buf)), "enough"),
		"Should render the words",
	)
}

@(test)
test_draw_text_wrapped_wraps_at_width :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	lines := draw_text_wrapped(&buf, {0, 0}, 10, "aaaa bbbb cccc dddd")
	testing.expect(t, lines > 1, "Should use more than one line")
}

@(test)
test_draw_text_wrapped_empty :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	lines := draw_text_wrapped(&buf, {0, 0}, 20, "")
	testing.expect_value(t, lines, 1)
}

@(test)
test_draw_text_wrapped_measures_cells_not_bytes :: proc(t: ^testing.T) {
	// Two-cell characters: 4 words of 2 cells each fit on one 20-cell line.
	// Measuring bytes instead would wrap after the second word.
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	lines := draw_text_wrapped(&buf, {0, 0}, 20, "你 好 世 界")
	testing.expect_value(t, lines, 1)
}

@(test)
test_draw_heading_underlines_level_one :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_heading(&buf, {0, 0}, "Title", 1)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "Title"), "Heading text")
	testing.expect(t, strings.contains(out, "═"), "Underline")
}

@(test)
test_draw_heading_level_two_has_no_underline :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_heading(&buf, {0, 0}, "Sub", 2)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "Sub"), "Heading text")
	testing.expect(t, !strings.contains(out, "═"), "No underline below level 1")
}

@(test)
test_draw_text_centered :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_text_centered(&buf, 0, 20, "hi")
	out := strings.to_string(buf)

	// (20 - 2) / 2 = 9 -> column 9 -> 1-based column 10
	testing.expect(t, strings.contains(out, "\x1b[1;10H"), "Should centre the text")
}

@(test)
test_draw_text_centered_wider_than_screen :: proc(t: ^testing.T) {
	// Regression: a negative column tripped print_at's assert.
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_text_centered(&buf, 0, 4, "far too long for this screen")
	testing.expect(t, strings.builder_len(buf) > 0, "Should render without crashing")
}

@(test)
test_draw_text_centered_uses_cell_width :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// "你好" is 4 cells: (20-4)/2 = 8 -> 1-based column 9
	draw_text_centered(&buf, 0, 20, "你好")
	testing.expect(t, strings.contains(strings.to_string(buf), "\x1b[1;9H"), "Cell-based centring")
}

@(test)
test_draw_banner_fills_width :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_banner(&buf, {0, 0}, 20, "Hi")
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "Hi"), "Banner text")
	testing.expect_value(t, munin.get_visible_width(out), 20)
}

@(test)
test_draw_banner_text_wider_than_banner :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_banner(&buf, {0, 0}, 4, "much longer text")
	testing.expect(t, strings.builder_len(buf) > 0, "Should render without crashing")
}

@(test)
test_draw_label_value :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_label_value(&buf, {0, 0}, "Name", "munin")
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "Name"), "Label")
	testing.expect(t, strings.contains(out, ": "), "Separator")
	testing.expect(t, strings.contains(out, "munin"), "Value")
}

@(test)
test_draw_label_value_custom_separator :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_label_value(&buf, {0, 0}, "k", "v", separator = " = ")
	testing.expect(
		t,
		strings.contains(munin.strip_ansi(strings.to_string(buf)), " = "),
		"Custom separator",
	)
}
