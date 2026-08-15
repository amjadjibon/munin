package munin

import "core:strings"
import "core:testing"

@(test)
test_visible_width :: proc(t: ^testing.T) {
	// ASCII
	testing.expect_value(t, get_visible_width("hello"), 5)

	// CJK (Double width)
	testing.expect_value(t, get_visible_width("你好"), 4) // 2 chars * 2 width

	// Mixed
	testing.expect_value(t, get_visible_width("A你好B"), 6) // 1 + 4 + 1

	// Emoji (Double width)
	testing.expect_value(t, get_visible_width("😀"), 2)
}

// ============================================================
// ESCAPE SEQUENCE WIDTH HANDLING (REGRESSION)
// ============================================================

@(test)
test_get_visible_width_cursor_sequence :: proc(t: ^testing.T) {
	// Terminating the escape scan only on 'm' meant a non-SGR sequence
	// swallowed the rest of the string and the width came back as 0.
	testing.expect_value(t, get_visible_width("\x1b[10;20Habc"), 3)
	testing.expect_value(t, get_visible_width("\x1b[2Jabc"), 3)
	testing.expect_value(t, get_visible_width("\x1b[31mabc\x1b[0m"), 3)
}

@(test)
test_get_visible_width_osc_sequence :: proc(t: ^testing.T) {
	testing.expect_value(t, get_visible_width("\x1b]0;title\x07abc"), 3)
	testing.expect_value(t, get_visible_width("\x1b]0;title\x1b\\abc"), 3)
}

@(test)
test_get_visible_width_matches_after_escape :: proc(t: ^testing.T) {
	// Mixed sequences must not affect the measured content width
	plain := get_visible_width("hello")
	decorated := get_visible_width("\x1b[H\x1b[1;32mhello\x1b[0m")
	testing.expect_value(t, decorated, plain)
}

@(test)
test_rune_width_matches_visual_width :: proc(t: ^testing.T) {
	// The two width tables used to disagree; rune_width now forwards.
	for r in ([]rune{'a', 'é', '你', '😀', '🚀', 'ﬀ'}) {
		testing.expect_value(t, rune_width(r), rune_visual_width(r))
	}
}

@(test)
test_get_max_width_multiline :: proc(t: ^testing.T) {
	testing.expect_value(t, get_max_width("ab\nabcd\na"), 4)
	testing.expect_value(t, get_max_width("abc"), 3)
	testing.expect_value(t, get_max_width(""), 0)
	testing.expect_value(t, get_max_width("\x1b[31mabcd\x1b[0m\nab"), 4)
}

// ============================================================
// JOIN TESTS
// ============================================================

@(test)
test_join_horizontal_side_by_side :: proc(t: ^testing.T) {
	out := join_horizontal(.Top, {"a\nb", "XY"})
	defer delete(out)
	testing.expect_value(t, out, "aXY\nb  ")
}

@(test)
test_join_horizontal_with_gap :: proc(t: ^testing.T) {
	out := join_horizontal(.Top, {"a", "b"}, 3)
	defer delete(out)
	testing.expect_value(t, out, "a   b")
}

@(test)
test_join_horizontal_pads_short_column :: proc(t: ^testing.T) {
	// The short column must be padded to its own width on every row, so the
	// right-hand column stays aligned.
	out := join_horizontal(.Top, {"wide\nw", "R1\nR2"})
	defer delete(out)

	lines := strings.split(out, "\n", context.temp_allocator)
	testing.expect_value(t, len(lines), 2)
	testing.expect_value(t, get_visible_width(lines[0]), get_visible_width(lines[1]))
}

@(test)
test_join_horizontal_bottom_alignment :: proc(t: ^testing.T) {
	out := join_horizontal(.Bottom, {"a\nb", "X"})
	defer delete(out)
	testing.expect_value(t, out, "a \nbX")
}

@(test)
test_join_horizontal_center_alignment :: proc(t: ^testing.T) {
	out := join_horizontal(.Center, {"a\nb\nc", "X"})
	defer delete(out)
	testing.expect_value(t, out, "a \nbX\nc ")
}

@(test)
test_join_horizontal_empty_input :: proc(t: ^testing.T) {
	out := join_horizontal(.Top, {})
	testing.expect_value(t, out, "")
}

@(test)
test_join_horizontal_single_model :: proc(t: ^testing.T) {
	out := join_horizontal(.Top, {"solo"})
	defer delete(out)
	testing.expect_value(t, out, "solo")
}

@(test)
test_join_horizontal_ignores_ansi_in_width :: proc(t: ^testing.T) {
	out := join_horizontal(.Top, {"\x1b[31mab\x1b[0m\n", "X\nY"})
	defer delete(out)

	lines := strings.split(out, "\n", context.temp_allocator)
	testing.expect_value(t, len(lines), 2)
	// Row 2 pads the (invisible) first column to 2 cells, then draws "Y"
	testing.expect_value(t, get_visible_width(lines[0]), get_visible_width(lines[1]))
}

@(test)
test_join_horizontal_wide_chars :: proc(t: ^testing.T) {
	out := join_horizontal(.Top, {"你好\n", "X\nY"})
	defer delete(out)

	lines := strings.split(out, "\n", context.temp_allocator)
	testing.expect_value(t, get_visible_width(lines[0]), get_visible_width(lines[1]))
}

@(test)
test_join_vertical_left :: proc(t: ^testing.T) {
	out := join_vertical(.Left, {"a", "bbb"})
	defer delete(out)
	testing.expect_value(t, out, "a  \nbbb")
}

@(test)
test_join_vertical_right :: proc(t: ^testing.T) {
	out := join_vertical(.Right, {"a", "bbb"})
	defer delete(out)
	testing.expect_value(t, out, "  a\nbbb")
}

@(test)
test_join_vertical_center :: proc(t: ^testing.T) {
	out := join_vertical(.Center, {"a", "bbb"})
	defer delete(out)
	testing.expect_value(t, out, " a \nbbb")
}

@(test)
test_join_vertical_empty_input :: proc(t: ^testing.T) {
	out := join_vertical(.Left, {})
	testing.expect_value(t, out, "")
}

@(test)
test_join_vertical_rows_same_width :: proc(t: ^testing.T) {
	out := join_vertical(.Center, {"short", "a much longer line", "mid"})
	defer delete(out)

	lines := strings.split(out, "\n", context.temp_allocator)
	expected := get_visible_width(lines[0])
	for line, i in lines {
		testing.expectf(t, get_visible_width(line) == expected, "Row %d width mismatch", i)
	}
}
