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

// ============================================================
// LIST STYLES AND SELECTION
// ============================================================

@(private = "file")
render_list :: proc(items: []List_Item, selected: int, style: List_Style) -> string {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_list(&buf, {0, 0}, items, selected, style)
	return strings.clone(munin.strip_ansi(strings.to_string(buf)), context.temp_allocator)
}

@(test)
test_draw_list_bullet_style :: proc(t: ^testing.T) {
	items := []List_Item{{text = "one"}, {text = "two"}}
	out := render_list(items, -1, .Bullet)

	testing.expect_value(t, strings.count(out, "•"), 2)
	testing.expect(t, strings.contains(out, "one"), "Item text")
	free_all(context.temp_allocator)
}

@(test)
test_draw_list_number_style :: proc(t: ^testing.T) {
	items := []List_Item{{text = "a"}, {text = "b"}, {text = "c"}}
	out := render_list(items, -1, .Number)

	testing.expect(t, strings.contains(out, "1."), "First index")
	testing.expect(t, strings.contains(out, "3."), "Last index")
	free_all(context.temp_allocator)
}

@(test)
test_draw_list_checkbox_style :: proc(t: ^testing.T) {
	items := []List_Item{{text = "done", checked = true}, {text = "todo", checked = false}}
	out := render_list(items, -1, .Checkbox)

	testing.expect(t, strings.contains(out, "[✓]"), "Checked marker")
	testing.expect(t, strings.contains(out, "[ ]"), "Unchecked marker")
	free_all(context.temp_allocator)
}

@(test)
test_draw_list_custom_marker :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	items := []List_Item{{text = "x"}}
	draw_list(&buf, {0, 0}, items, -1, .Custom, ">>")

	testing.expect(
		t,
		strings.contains(munin.strip_ansi(strings.to_string(buf)), ">>"),
		"Custom marker",
	)
	free_all(context.temp_allocator)
}

@(test)
test_draw_list_selection_indicator :: proc(t: ^testing.T) {
	items := []List_Item{{text = "one"}, {text = "two"}}

	selected := render_list(items, 1, .Bullet)
	testing.expect(t, strings.contains(selected, "►"), "Selected row is marked")

	none := render_list(items, -1, .Bullet)
	testing.expect(t, !strings.contains(none, "►"), "No marker when nothing is selected")
	free_all(context.temp_allocator)
}

@(test)
test_draw_list_out_of_range_selection :: proc(t: ^testing.T) {
	items := []List_Item{{text = "one"}}
	out := render_list(items, 99, .Bullet)

	testing.expect(t, strings.contains(out, "one"), "Should still render the list")
	testing.expect(t, !strings.contains(out, "►"), "Nothing is selected")
	free_all(context.temp_allocator)
}

@(test)
test_draw_list_empty :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	items := []List_Item{}
	draw_list(&buf, {0, 0}, items, -1)
	testing.expect_value(t, strings.builder_len(buf), 0)
}

@(test)
test_draw_list_item_color_is_used :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	items := []List_Item{{text = "red", color = munin.Basic_Color.Red}}
	draw_list(&buf, {0, 0}, items, -1)

	testing.expect(t, strings.contains(strings.to_string(buf), "\x1b[31m"), "Item color")
	free_all(context.temp_allocator)
}

@(test)
test_draw_list_scrollable_shows_indicators :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	items := []List_Item{{text = "a"}, {text = "b"}, {text = "c"}, {text = "d"}}
	draw_list_scrollable(&buf, {0, 2}, 2, items, 2, 1)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "More above"), "Should hint at hidden items above")
	testing.expect(t, strings.contains(out, "More below"), "Should hint at hidden items below")
	free_all(context.temp_allocator)
}

@(test)
test_draw_list_scrollable_zero_height :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	items := []List_Item{{text = "a"}}
	draw_list_scrollable(&buf, {0, 0}, 0, items, 0, 0)
	testing.expect_value(t, strings.builder_len(buf), 0)
}
