package components

import munin ".."
import "core:strings"
import "core:testing"

// ============================================================
// PROGRESS BAR COMPONENT
// ============================================================

// Count how many times a (possibly multi-byte) needle occurs.
@(private = "file")
count :: proc(haystack, needle: string) -> int {
	return strings.count(haystack, needle)
}

@(test)
test_progress_bar_fill_ratio :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_progress_bar(&buf, {0, 0}, 10, 50, .Blocks, show_percent = false)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect_value(t, count(out, "█"), 5)
	testing.expect_value(t, count(out, "░"), 5)
}

@(test)
test_progress_bar_empty_and_full :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_progress_bar(&buf, {0, 0}, 8, 0, .Blocks, show_percent = false)
	empty := munin.strip_ansi(strings.to_string(buf))
	testing.expect_value(t, count(empty, "█"), 0)
	testing.expect_value(t, count(empty, "░"), 8)

	strings.builder_reset(&buf)
	draw_progress_bar(&buf, {0, 0}, 8, 100, .Blocks, show_percent = false)
	full := munin.strip_ansi(strings.to_string(buf))
	testing.expect_value(t, count(full, "█"), 8)
	testing.expect_value(t, count(full, "░"), 0)
}

@(test)
test_progress_bar_clamps_out_of_range :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Over 100% must not draw more cells than the bar is wide.
	draw_progress_bar(&buf, {0, 0}, 6, 500, .Blocks, show_percent = false)
	over := munin.strip_ansi(strings.to_string(buf))
	testing.expect_value(t, count(over, "█"), 6)

	strings.builder_reset(&buf)
	draw_progress_bar(&buf, {0, 0}, 6, -50, .Blocks, show_percent = false)
	under := munin.strip_ansi(strings.to_string(buf))
	testing.expect_value(t, count(under, "█"), 0)
	testing.expect_value(t, count(under, "░"), 6)
}

@(test)
test_progress_bar_zero_width :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_progress_bar(&buf, {0, 0}, 0, 50, .Blocks, show_percent = false)
	out := munin.strip_ansi(strings.to_string(buf))
	testing.expect_value(t, count(out, "█"), 0)
	testing.expect_value(t, count(out, "░"), 0)
}

@(test)
test_progress_bar_every_style_keeps_total_width :: proc(t: ^testing.T) {
	for style in Progress_Style {
		buf := strings.builder_make()
		defer strings.builder_destroy(&buf)

		draw_progress_bar(&buf, {0, 0}, 10, 40, style, show_percent = false)
		out := munin.strip_ansi(strings.to_string(buf))

		// Drop the leading cursor-position sequence, then measure.
		testing.expectf(
			t,
			munin.get_visible_width(out) == 10,
			"%v drew %d cells, expected 10",
			style,
			munin.get_visible_width(out),
		)
	}
}

@(test)
test_progress_bar_arrow_style_has_head :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_progress_bar(&buf, {0, 0}, 10, 50, .Arrow, show_percent = false)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect_value(t, count(out, ">"), 1)
	testing.expect_value(t, count(out, "="), 4)
	testing.expect_value(t, count(out, "-"), 5)
}

@(test)
test_progress_bar_shows_percentage :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_progress_bar(&buf, {0, 0}, 10, 42, .Blocks, show_percent = true)
	testing.expect(
		t,
		strings.contains(munin.strip_ansi(strings.to_string(buf)), "42%"),
		"Should render the percentage",
	)
}

@(test)
test_progress_bar_vertical_fill :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_progress_bar_vertical(&buf, 0, 0, 10, 30)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect_value(t, count(out, "█"), 3)
	testing.expect_value(t, count(out, "░"), 7)
}

@(test)
test_progress_bar_boxed_has_brackets :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_progress_bar_boxed(&buf, 0, 0, 10, 50, "Loading")
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "["), "Opening bracket")
	testing.expect(t, strings.contains(out, "]"), "Closing bracket")
	testing.expect(t, strings.contains(out, "Loading"), "Label")
}
