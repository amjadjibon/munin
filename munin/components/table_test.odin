package components

import munin ".."
import "core:strings"
import "core:testing"

@(test)
test_draw_table_does_not_split_utf8_when_cell_matches_width :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	columns := []Table_Column {
		{title = "Title", width = 10, align = .Left},
	}
	rows := [][]string {
		{"abcdefghi…"},
	}

	draw_table(&buf, {0, 0}, columns, rows)
	output := strings.to_string(buf)

	testing.expect(t, strings.contains(output, "abcdefghi…"), "Should preserve full UTF-8 ellipsis")
	testing.expect(t, !strings.contains(output, "�"), "Should not emit replacement characters")
	testing.expect_value(t, munin.get_visible_width("abcdefghi…"), 10)
}

// ============================================================
// MALFORMED UTF-8 HANDLING (REGRESSION)
// ============================================================

@(test)
test_truncate_invalid_utf8_no_overrun :: proc(t: ^testing.T) {
	// Each bad byte decoded to RUNE_ERROR, which was re-encoded as 3 bytes
	// while only 1 was consumed - byte_pos ran past the end of the string and
	// the slice went out of bounds.
	out := truncate_visible_width("\xff\xff\xff\xff", 10)
	testing.expect(t, len(out) <= 4, "Must not slice past the end of the input")
}

@(test)
test_truncate_mixed_invalid_utf8 :: proc(t: ^testing.T) {
	out := truncate_visible_width("ab\xffcd", 10)
	testing.expect(t, len(out) <= 5, "Must not slice past the end of the input")
}

@(test)
test_truncate_respects_char_boundaries :: proc(t: ^testing.T) {
	// "你好" is 2 runes of width 2 each; width 2 fits exactly one.
	testing.expect_value(t, truncate_visible_width("你好", 2), "你")
	testing.expect_value(t, truncate_visible_width("你好", 3), "你")
	testing.expect_value(t, truncate_visible_width("你好", 4), "你好")
}

@(test)
test_truncate_zero_width :: proc(t: ^testing.T) {
	testing.expect_value(t, truncate_visible_width("abc", 0), "")
	testing.expect_value(t, truncate_visible_width("abc", -5), "")
}

@(test)
test_pad_string_narrower_than_content :: proc(t: ^testing.T) {
	testing.expect_value(t, pad_string("abcdef", 3, .Left), "abc")
}

// ============================================================
// TABLE RENDERING
// ============================================================

@(test)
test_draw_table_renders_header_and_rows :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	columns := []Table_Column{{title = "Name", width = 8}, {title = "Qty", width = 5}}
	rows := [][]string{{"apple", "3"}, {"pear", "12"}}

	draw_table(&buf, {0, 0}, columns, rows)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "Name"), "Header")
	testing.expect(t, strings.contains(out, "apple"), "First row")
	testing.expect(t, strings.contains(out, "12"), "Second row")
	testing.expect(t, strings.contains(out, "┌"), "Top border")
	testing.expect(t, strings.contains(out, "┴"), "Bottom joint")
	free_all(context.temp_allocator)
}

@(test)
test_draw_table_no_columns_draws_nothing :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_table(&buf, {0, 0}, {}, {})
	testing.expect_value(t, strings.builder_len(buf), 0)
}

@(test)
test_draw_table_missing_cells_are_blank :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	columns := []Table_Column{{title = "A", width = 4}, {title = "B", width = 4}}
	rows := [][]string{{"only"}} // second cell missing

	draw_table(&buf, {0, 0}, columns, rows)
	testing.expect(
		t,
		strings.contains(munin.strip_ansi(strings.to_string(buf)), "only"),
		"Should render the present cell",
	)
	free_all(context.temp_allocator)
}

@(test)
test_draw_table_invalid_utf8_cell :: proc(t: ^testing.T) {
	// Regression: malformed cell data used to slice out of bounds.
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	columns := []Table_Column{{title = "A", width = 3}}
	rows := [][]string{{"\xff\xfe\xfd\xfc\xfb"}}

	draw_table(&buf, {0, 0}, columns, rows)
	testing.expect(t, strings.builder_len(buf) > 0, "Should render without crashing")
	free_all(context.temp_allocator)
}

@(test)
test_pad_string_alignments :: proc(t: ^testing.T) {
	testing.expect_value(t, pad_string("ab", 6, .Left), "ab    ")
	testing.expect_value(t, pad_string("ab", 6, .Right), "    ab")
	testing.expect_value(t, pad_string("ab", 6, .Center), "  ab  ")
	free_all(context.temp_allocator)
}

@(test)
test_pad_string_exact_width_is_unchanged :: proc(t: ^testing.T) {
	testing.expect_value(t, pad_string("abc", 3, .Left), "abc")
}

@(test)
test_pad_string_wide_characters :: proc(t: ^testing.T) {
	// "你好" is 4 cells wide, so a 6-cell column needs 2 spaces.
	testing.expect_value(t, munin.get_visible_width(pad_string("你好", 6, .Left)), 6)
	free_all(context.temp_allocator)
}
