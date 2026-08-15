package components

import munin ".."
import "core:strings"
import "core:testing"

// ============================================================
// PAGINATION - PAGE MATH
// ============================================================

@(test)
test_calculate_pages_rounds_up :: proc(t: ^testing.T) {
	testing.expect_value(t, calculate_pages(10, 10), 1)
	testing.expect_value(t, calculate_pages(11, 10), 2)
	testing.expect_value(t, calculate_pages(19, 10), 2)
	testing.expect_value(t, calculate_pages(20, 10), 2)
	testing.expect_value(t, calculate_pages(1, 10), 1)
}

@(test)
test_calculate_pages_edge_cases :: proc(t: ^testing.T) {
	testing.expect_value(t, calculate_pages(0, 10), 0)
	testing.expect_value(t, calculate_pages(10, 0), 0)
	testing.expect_value(t, calculate_pages(10, -1), 0)
}

@(test)
test_get_page_slice_basic :: proc(t: ^testing.T) {
	items := []int{1, 2, 3, 4, 5, 6, 7}

	testing.expect_value(t, len(get_page_slice(items, 1, 3)), 3)
	testing.expect_value(t, get_page_slice(items, 1, 3)[0], 1)
	testing.expect_value(t, get_page_slice(items, 2, 3)[0], 4)
	// Last page is partial
	testing.expect_value(t, len(get_page_slice(items, 3, 3)), 1)
	testing.expect_value(t, get_page_slice(items, 3, 3)[0], 7)
}

@(test)
test_get_page_slice_out_of_range :: proc(t: ^testing.T) {
	items := []int{1, 2, 3}

	testing.expect_value(t, len(get_page_slice(items, 99, 3)), 0)
	testing.expect_value(t, len(get_page_slice(items, 0, 3)), 0)
	testing.expect_value(t, len(get_page_slice(items, -5, 3)), 0)
}

@(test)
test_get_page_slice_empty_input :: proc(t: ^testing.T) {
	items := []int{}
	testing.expect_value(t, len(get_page_slice(items, 1, 10)), 0)
}

// ============================================================
// PAGINATION - RENDERING
// ============================================================

@(test)
test_draw_pagination_zero_pages_draws_nothing :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_pagination(&buf, {0, 0}, 1, 0)
	testing.expect_value(t, strings.builder_len(buf), 0)
}

@(test)
test_draw_pagination_numbers_shows_all_when_few :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_pagination(&buf, {0, 0}, 2, 4, .Numbers)
	out := munin.strip_ansi(strings.to_string(buf))

	for page in ([]string{"1", "2", "3", "4"}) {
		testing.expectf(t, strings.contains(out, page), "Page %s should be listed", page)
	}
	testing.expect(t, !strings.contains(out, "..."), "No ellipsis needed for 4 pages")
}

@(test)
test_draw_pagination_numbers_elides_when_many :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_pagination(&buf, {0, 0}, 50, 100, .Numbers, 5)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "..."), "Should elide distant pages")
	testing.expect(t, strings.contains(out, "50"), "Current page should be shown")
	testing.expect(t, strings.contains(out, "100"), "Last page should be shown")
}

@(test)
test_draw_pagination_numbers_at_boundaries :: proc(t: ^testing.T) {
	// First and last page must not produce a negative or empty window.
	for page in ([]int{1, 2, 99, 100}) {
		buf := strings.builder_make()
		defer strings.builder_destroy(&buf)

		draw_pagination(&buf, {0, 0}, page, 100, .Numbers, 7)
		testing.expectf(t, strings.builder_len(buf) > 0, "Page %d should render", page)
	}
}

@(test)
test_draw_pagination_arrows_style :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_pagination(&buf, {0, 0}, 3, 7, .Arrows)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "3/7"), "Should show the page indicator")
	testing.expect(t, strings.contains(out, "←"), "Should show a previous arrow")
	testing.expect(t, strings.contains(out, "→"), "Should show a next arrow")
}

@(test)
test_draw_pagination_dots_style :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_pagination(&buf, {0, 0}, 2, 5, .Dots)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect_value(t, strings.count(out, "●"), 1) // current page
	testing.expect_value(t, strings.count(out, "○"), 4) // the rest
}

@(test)
test_draw_pagination_compact_style :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_pagination(&buf, {0, 0}, 3, 9, .Compact)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "Page 3 of 9"), "Should show a compact indicator")
	testing.expect(t, strings.contains(out, "Prev"), "Should offer previous")
	testing.expect(t, strings.contains(out, "Next"), "Should offer next")
}

@(test)
test_draw_pagination_compact_hides_unavailable_nav :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_pagination(&buf, {0, 0}, 1, 1, .Compact)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, !strings.contains(out, "Prev"), "No previous page exists")
	testing.expect(t, !strings.contains(out, "Next"), "No next page exists")
}

@(test)
test_draw_pagination_with_info :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_pagination_with_info(&buf, {0, 2}, 2, 5, 10, 47)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "11-20"), "Should show the item range")
	testing.expect(t, strings.contains(out, "47"), "Should show the total")
}

@(test)
test_draw_pagination_with_info_last_partial_page :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_pagination_with_info(&buf, {0, 2}, 5, 5, 10, 47)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "41-47"), "Last page should clamp to the total")
}
