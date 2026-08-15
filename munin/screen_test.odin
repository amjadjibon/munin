package munin

import "core:strings"
import "core:testing"

// ============================================================
// PAINTING
// ============================================================

@(private = "file")
paint :: proc(s: ^Screen, draw: proc(buf: ^strings.Builder)) {
	b := strings.builder_make(context.temp_allocator)
	draw(&b)
	screen_paint(s, strings.to_string(b))
}

@(test)
test_screen_paints_plain_text :: proc(t: ^testing.T) {
	s := screen_make(10, 3)
	defer screen_destroy(&s)

	screen_paint(&s, "hi")
	testing.expect_value(t, screen_row_text(&s, 0), "hi")
	free_all(context.temp_allocator)
}

@(test)
test_screen_honours_absolute_cursor_moves :: proc(t: ^testing.T) {
	s := screen_make(20, 5)
	defer screen_destroy(&s)

	// This is exactly what the components emit.
	screen_paint(&s, "\x1b[3;5Hhello")

	testing.expect_value(t, screen_row_text(&s, 2), "    hello")
	testing.expect_value(t, screen_row_text(&s, 0), "")
	free_all(context.temp_allocator)
}

@(test)
test_screen_newline_returns_to_column_zero :: proc(t: ^testing.T) {
	s := screen_make(10, 3)
	defer screen_destroy(&s)

	screen_paint(&s, "ab\ncd")
	testing.expect_value(t, screen_row_text(&s, 0), "ab")
	testing.expect_value(t, screen_row_text(&s, 1), "cd")
	free_all(context.temp_allocator)
}

@(test)
test_screen_clips_everything_outside_the_grid :: proc(t: ^testing.T) {
	// Drawing past the edge is dropped instead of wrapping and corrupting
	// the rest of the display.
	s := screen_make(5, 2)
	defer screen_destroy(&s)

	screen_paint(&s, "abcdefghij") // wider than the screen
	screen_paint(&s, "\x1b[9;1Hoff the bottom")
	screen_paint(&s, "\x1b[1;99Hoff the right")

	testing.expect_value(t, screen_row_text(&s, 0), "abcde")
	testing.expect_value(t, screen_row_text(&s, 1), "")
	free_all(context.temp_allocator)
}

@(test)
test_screen_paints_at_an_origin :: proc(t: ^testing.T) {
	// Composition: a component that draws at {0,0} placed inside a region.
	s := screen_make(20, 6)
	defer screen_destroy(&s)

	screen_paint(&s, "\x1b[1;1Hbox", {5, 2}, {10, 3})

	testing.expect_value(t, screen_row_text(&s, 2), "     box")
	free_all(context.temp_allocator)
}

@(test)
test_screen_clips_to_the_region :: proc(t: ^testing.T) {
	s := screen_make(20, 6)
	defer screen_destroy(&s)

	// A 4x2 region at {2,1}: everything past it is dropped, and in
	// particular it must not spill into the neighbouring column.
	screen_paint(&s, "abcdefghij\nklmnopqrst\nuvwxyz", {2, 1}, {4, 2})

	testing.expect_value(t, screen_row_text(&s, 1), "  abcd")
	testing.expect_value(t, screen_row_text(&s, 2), "  klmn")
	testing.expect_value(t, screen_row_text(&s, 3), "")
	free_all(context.temp_allocator)
}

@(test)
test_screen_two_components_side_by_side :: proc(t: ^testing.T) {
	// The composition problem: two absolutely-positioned components that both
	// draw at {0,0} still end up next to each other.
	s := screen_make(24, 4)
	defer screen_destroy(&s)

	left := strings.builder_make(context.temp_allocator)
	draw_box(&left, {0, 0}, 8, 3)
	right := strings.builder_make(context.temp_allocator)
	draw_box(&right, {0, 0}, 8, 3)

	screen_paint(&s, strings.to_string(left), {0, 0}, {8, 3})
	screen_paint(&s, strings.to_string(right), {10, 0}, {8, 3})

	row := screen_row_text(&s, 0)
	testing.expect_value(t, row, "┌──────┐  ┌──────┐")
	free_all(context.temp_allocator)
}

@(test)
test_screen_erase_display :: proc(t: ^testing.T) {
	s := screen_make(6, 2)
	defer screen_destroy(&s)

	screen_paint(&s, "abcdef\nghijkl")
	testing.expect_value(t, screen_row_text(&s, 1), "ghijkl")

	// What clear_screen() emits.
	screen_paint(&s, "\x1b[H\x1b[J")
	testing.expect_value(t, screen_row_text(&s, 0), "")
	testing.expect_value(t, screen_row_text(&s, 1), "")
	free_all(context.temp_allocator)
}

@(test)
test_screen_erase_line :: proc(t: ^testing.T) {
	s := screen_make(6, 2)
	defer screen_destroy(&s)

	screen_paint(&s, "abcdef\nghijkl")
	screen_paint(&s, "\x1b[1;3H\x1b[K") // erase from column 3 to end of row 1

	testing.expect_value(t, screen_row_text(&s, 0), "ab")
	testing.expect_value(t, screen_row_text(&s, 1), "ghijkl")
	free_all(context.temp_allocator)
}

@(test)
test_screen_tracks_colors_and_attributes :: proc(t: ^testing.T) {
	s := screen_make(8, 1)
	defer screen_destroy(&s)

	screen_paint(&s, "\x1b[1m\x1b[31mR\x1b[0mn")

	styled, _ := screen_cell(&s, 0, 0)
	plain, _ := screen_cell(&s, 1, 0)

	testing.expect_value(t, styled.r, 'R')
	testing.expect_value(t, styled.fg, Color(Basic_Color.Red))
	testing.expect(t, .Bold in styled.attrs, "bold should be recorded")

	testing.expect_value(t, plain.r, 'n')
	testing.expect_value(t, plain.fg, Color(Basic_Color.Reset))
	testing.expect(t, plain.attrs == {}, "attributes should have been reset")
	free_all(context.temp_allocator)
}

@(test)
test_screen_tracks_extended_colors :: proc(t: ^testing.T) {
	s := screen_make(4, 1)
	defer screen_destroy(&s)

	screen_paint(&s, "\x1b[38;2;1;2;3m\x1b[48;5;42mx")

	c, _ := screen_cell(&s, 0, 0)
	testing.expect_value(t, c.fg, Color(RGB{1, 2, 3}))
	testing.expect_value(t, c.bg, Color(ANSI256(42)))
	free_all(context.temp_allocator)
}

@(test)
test_screen_wide_characters_occupy_two_cells :: proc(t: ^testing.T) {
	s := screen_make(6, 1)
	defer screen_destroy(&s)

	screen_paint(&s, "你a")

	wide, _ := screen_cell(&s, 0, 0)
	cont, _ := screen_cell(&s, 1, 0)
	next, _ := screen_cell(&s, 2, 0)

	testing.expect_value(t, wide.r, '你')
	testing.expect_value(t, wide.width, 2)
	testing.expect_value(t, cont.width, 0) // continuation half
	testing.expect_value(t, next.r, 'a')
	free_all(context.temp_allocator)
}

@(test)
test_screen_ignores_private_and_osc_sequences :: proc(t: ^testing.T) {
	s := screen_make(8, 1)
	defer screen_destroy(&s)

	screen_paint(&s, "\x1b[?25l\x1b]0;title\x07ok\x1b[?1049h")
	testing.expect_value(t, screen_row_text(&s, 0), "ok")
	free_all(context.temp_allocator)
}

// ============================================================
// DIFFING
// ============================================================

@(private = "file")
render_diff :: proc(cur, prev: ^Screen) -> string {
	b := strings.builder_make(context.temp_allocator)
	screen_render_diff(cur, prev, &b)
	return strings.to_string(b)
}

@(test)
test_screen_diff_of_identical_screens_is_empty :: proc(t: ^testing.T) {
	a := screen_make(20, 5)
	defer screen_destroy(&a)
	b := screen_make(20, 5)
	defer screen_destroy(&b)

	screen_paint(&a, "\x1b[2;2Hhello")
	screen_paint(&b, "\x1b[2;2Hhello")

	testing.expect_value(t, len(render_diff(&a, &b)), 0)
	free_all(context.temp_allocator)
}

@(test)
test_screen_diff_emits_only_changed_cells :: proc(t: ^testing.T) {
	prev := screen_make(40, 10)
	defer screen_destroy(&prev)
	cur := screen_make(40, 10)
	defer screen_destroy(&cur)

	screen_paint(&prev, "\x1b[5;1HCounter: 7")
	screen_paint(&cur, "\x1b[5;1HCounter: 8")

	out := render_diff(&cur, &prev)

	// One cell changed: a position, the character, and a trailing reset.
	testing.expect(t, strings.contains(out, "8"), "should send the new character")
	testing.expect(t, !strings.contains(out, "Counter"), "should not resend the label")
	testing.expectf(t, len(out) < 20, "diff was %d bytes: %q", len(out), out)
	free_all(context.temp_allocator)
}

@(test)
test_screen_diff_against_nil_redraws_everything :: proc(t: ^testing.T) {
	cur := screen_make(10, 2)
	defer screen_destroy(&cur)
	screen_paint(&cur, "hello")

	out := render_diff(&cur, nil)
	testing.expect(t, strings.contains(out, "\x1b[2J"), "should clear first")
	testing.expect(t, strings.contains(out, "hello"), "should send everything")
	free_all(context.temp_allocator)
}

@(test)
test_screen_diff_after_resize_redraws_everything :: proc(t: ^testing.T) {
	prev := screen_make(10, 2)
	defer screen_destroy(&prev)
	cur := screen_make(20, 4)
	defer screen_destroy(&cur)
	screen_paint(&cur, "hello")

	out := render_diff(&cur, &prev)
	testing.expect(t, strings.contains(out, "hello"), "a resized screen is redrawn in full")
	free_all(context.temp_allocator)
}

@(test)
test_screen_diff_round_trips_through_a_screen :: proc(t: ^testing.T) {
	// Painting a diff onto the previous screen must produce the new screen:
	// that is the property that makes incremental rendering correct.
	prev := screen_make(30, 6)
	defer screen_destroy(&prev)
	cur := screen_make(30, 6)
	defer screen_destroy(&cur)

	screen_paint(&prev, "\x1b[1;1H\x1b[31mred\x1b[0m\x1b[3;5Hmiddle\x1b[6;1Hbottom")
	screen_paint(&cur, "\x1b[1;1H\x1b[31mred\x1b[0m\x1b[3;5HMIDDLE\x1b[6;1Hbottom!")

	out := render_diff(&cur, &prev)

	replay := screen_make(30, 6)
	defer screen_destroy(&replay)
	screen_paint(&replay, "\x1b[1;1H\x1b[31mred\x1b[0m\x1b[3;5Hmiddle\x1b[6;1Hbottom")
	screen_paint(&replay, out)

	for y in 0 ..< cur.height {
		testing.expectf(
			t,
			screen_row_text(&replay, y) == screen_row_text(&cur, y),
			"row %d: %q != %q",
			y,
			screen_row_text(&replay, y),
			screen_row_text(&cur, y),
		)
	}
	free_all(context.temp_allocator)
}

@(test)
test_screen_diff_restores_styling_of_changed_cells :: proc(t: ^testing.T) {
	prev := screen_make(10, 1)
	defer screen_destroy(&prev)
	cur := screen_make(10, 1)
	defer screen_destroy(&cur)

	screen_paint(&cur, "\x1b[1;5H\x1b[32mg")

	out := render_diff(&cur, &prev)
	testing.expect(t, strings.contains(out, "\x1b[32m"), "changed cell carries its colour")

	replay := screen_make(10, 1)
	defer screen_destroy(&replay)
	screen_paint(&replay, out)

	c, _ := screen_cell(&replay, 4, 0)
	testing.expect_value(t, c.r, 'g')
	testing.expect_value(t, c.fg, Color(Basic_Color.Green))
	free_all(context.temp_allocator)
}

// ============================================================
// BLIT AND RESIZE
// ============================================================

@(test)
test_screen_blit_clips_at_the_destination_edge :: proc(t: ^testing.T) {
	dst := screen_make(10, 3)
	defer screen_destroy(&dst)
	src := screen_make(6, 2)
	defer screen_destroy(&src)

	screen_paint(&src, "abcdef\nghijkl")
	screen_blit(&dst, &src, {7, 0}) // only 3 columns fit

	testing.expect_value(t, screen_row_text(&dst, 0), "       abc")
	free_all(context.temp_allocator)
}

@(test)
test_screen_resize_reports_changes :: proc(t: ^testing.T) {
	s := screen_make(10, 3)
	defer screen_destroy(&s)

	testing.expect(t, screen_resize(&s, 20, 6), "size changed")
	testing.expect_value(t, s.width, 20)
	testing.expect_value(t, s.height, 6)
	testing.expect(t, !screen_resize(&s, 20, 6), "same size is not a change")
}

@(test)
test_screen_zero_size_is_safe :: proc(t: ^testing.T) {
	s := screen_make(0, 0)
	defer screen_destroy(&s)

	screen_paint(&s, "\x1b[1;1Hanything\n\x1b[J")
	testing.expect_value(t, len(render_diff(&s, nil)), 7) // just the clear
	free_all(context.temp_allocator)
}

@(test)
test_zero_value_screen_can_be_resized :: proc(t: ^testing.T) {
	// A Program's screens start as zero values, so their allocator is nil.
	// Handing that to make() returned an empty slice while width/height said
	// otherwise, and the first paint indexed out of bounds.
	s: Screen
	defer screen_destroy(&s)

	screen_resize(&s, 10, 3)
	testing.expect_value(t, len(s.cells), 30)

	screen_paint(&s, "\x1b[2;2Hok")
	testing.expect_value(t, screen_row_text(&s, 1), " ok")
	free_all(context.temp_allocator)
}
