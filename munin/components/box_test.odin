package components

import munin ".."
import "core:strings"
import "core:testing"

// ============================================================
// BOX COMPONENT
// ============================================================

@(test)
test_box_styles_have_all_characters :: proc(t: ^testing.T) {
	for style in Box_Style {
		b := BOX_STYLES[style]
		testing.expectf(t, len(b.top_left) > 0, "%v missing top_left", style)
		testing.expectf(t, len(b.top_right) > 0, "%v missing top_right", style)
		testing.expectf(t, len(b.bottom_left) > 0, "%v missing bottom_left", style)
		testing.expectf(t, len(b.bottom_right) > 0, "%v missing bottom_right", style)
		testing.expectf(t, len(b.horizontal) > 0, "%v missing horizontal", style)
		testing.expectf(t, len(b.vertical) > 0, "%v missing vertical", style)
	}
}

@(test)
test_draw_box_styled_corners :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_box_styled(&buf, {0, 0}, 6, 3, .Single)
	out := strings.to_string(buf)

	testing.expect(t, strings.contains(out, "┌────┐"), "Top border")
	testing.expect(t, strings.contains(out, "└────┘"), "Bottom border")
	testing.expect(t, strings.contains(out, "│"), "Vertical sides")
}

@(test)
test_draw_box_styled_ascii :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_box_styled(&buf, {0, 0}, 5, 3, .Ascii)
	out := strings.to_string(buf)

	testing.expect(t, strings.contains(out, "+---+"), "ASCII top border")
	testing.expect(t, strings.contains(out, "|"), "ASCII sides")
}

@(test)
test_draw_box_styled_emits_color :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_box_styled(&buf, {0, 0}, 4, 3, .Single, munin.Basic_Color.BrightRed)
	testing.expect(t, strings.contains(strings.to_string(buf), "\x1b[91m"), "Should emit color")
}

@(test)
test_draw_box_titled_includes_title :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_box_titled(&buf, {0, 0}, 20, 4, "Hello")
	testing.expect(t, strings.contains(strings.to_string(buf), "Hello"), "Title should appear")
}

@(test)
test_draw_box_titled_truncates_long_title :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// max_title_width is width-4 = 4
	draw_box_titled(&buf, {0, 0}, 8, 3, "abcdefghij")
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "abcd"), "Should keep what fits")
	testing.expect(t, !strings.contains(out, "abcde"), "Should cut at the limit")
}

@(test)
test_draw_box_titled_invalid_utf8_title :: proc(t: ^testing.T) {
	// Regression: the open-coded truncation re-encoded RUNE_ERROR as 3 bytes
	// while consuming 1, running the slice past the end of the string.
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_box_titled(&buf, {0, 0}, 8, 3, "\xff\xff\xff\xff\xff\xff\xff\xff")
	testing.expect(t, strings.builder_len(buf) > 0, "Should render without crashing")
}

@(test)
test_draw_box_titled_multibyte_title_not_split :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Width 8 -> max title width 4 -> exactly two wide characters.
	draw_box_titled(&buf, {0, 0}, 8, 3, "你好世界")
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "你好"), "Should keep the characters that fit")
	testing.expect(t, !strings.contains(out, "你好世"), "Should not overflow the border")
}

@(test)
test_draw_box_titled_empty_title :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_box_styled(&buf, {0, 0}, 10, 3, .Single)
	plain := strings.clone(strings.to_string(buf), context.temp_allocator)

	strings.builder_reset(&buf)
	draw_box_titled(&buf, {0, 0}, 10, 3, "")

	testing.expect_value(t, strings.to_string(buf), plain)
	free_all(context.temp_allocator)
}

@(test)
test_draw_box_titled_tiny_box_has_no_title :: proc(t: ^testing.T) {
	// width 4 -> max_title_width 0, so the title is dropped entirely
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_box_titled(&buf, {0, 0}, 4, 3, "title")
	testing.expect(
		t,
		!strings.contains(strings.to_string(buf), "title"),
		"No room for a title",
	)
}

@(test)
test_draw_box_filled_fills_interior :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_box_filled(&buf, {0, 0}, 5, 3, munin.Basic_Color.Blue)
	out := strings.to_string(buf)

	testing.expect(t, strings.contains(out, "\x1b[44m"), "Should set the background")
	testing.expect(t, strings.contains(out, "┌"), "Should still draw a border")
}
