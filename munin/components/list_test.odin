package components

import munin ".."
import "core:strings"
import "core:testing"

@(test)
test_draw_list_scrollable_clamps_negative_offset :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	items := []List_Item {
		{text = "First"},
		{text = "Second"},
	}

	draw_list_scrollable(&buf, {0, 0}, 1, items, 0, -10)
	output := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(output, "First"), "Should draw from the first item")
	testing.expect(t, !strings.contains(output, "Second"), "Should respect visible height")
}

@(test)
test_draw_list_scrollable_clamps_large_offset :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	items := []List_Item {
		{text = "First"},
		{text = "Second"},
	}

	draw_list_scrollable(&buf, {0, 0}, 3, items, 0, 100)
	testing.expect_value(t, munin.strip_ansi(strings.to_string(buf)), "")
}

@(test)
test_draw_list_scrollable_ignores_zero_height :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	items := []List_Item {
		{text = "First"},
	}

	draw_list_scrollable(&buf, {0, 0}, 0, items, 0, 0)
	testing.expect_value(t, strings.to_string(buf), "")
}
