package components

import munin ".."
import "core:strings"
import "core:testing"

// ============================================================
// UNTRUSTED TEXT MUST NOT REACH THE TERMINAL
// ============================================================

// An OSC 52 sequence writes the user's clipboard; a CSI moves the cursor.
// Both are things a database value or a filename must never be able to do.
@(private = "file")
EVIL :: "bob\x1b]52;c;cm93bmVk\x07\x1b[2Jx"

@(private = "file")
assert_clean :: proc(t: ^testing.T, out: string, what: string) {
	testing.expectf(t, !strings.contains(out, "\x1b]52;"), "%s leaked OSC 52", what)
	testing.expectf(t, !strings.contains(out, "\x1b[2J"), "%s leaked a CSI erase", what)
	testing.expectf(t, !strings.contains(out, "\x07"), "%s leaked BEL", what)
}

@(test)
test_table_sanitizes_cells_and_headers :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	columns := []Table_Column{{title = EVIL, width = 12}}
	rows := [][]string{{EVIL}}
	draw_table(&buf, {0, 0}, columns, rows)

	out := strings.to_string(buf)
	assert_clean(t, out, "draw_table")
	testing.expect(t, strings.contains(out, "bob"), "should still show the text")
	free_all(context.temp_allocator)
}

@(test)
test_table_sanitize_can_be_opted_out :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	columns := []Table_Column{{title = "t", width = 12}}
	rows := [][]string{{"\x1b[31mred\x1b[0m"}}
	draw_table(&buf, {0, 0}, columns, rows, sanitize = false)

	testing.expect(
		t,
		strings.contains(strings.to_string(buf), "\x1b[31m"),
		"opting out keeps the caller's own styling",
	)
	free_all(context.temp_allocator)
}

@(test)
test_table_sanitizes_regardless_of_column_width :: proc(t: ^testing.T) {
	// Escape sequences measure zero cells, so narrow columns never truncated
	// them away.
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	columns := []Table_Column{{title = "t", width = 2}}
	rows := [][]string{{EVIL}}
	draw_table(&buf, {0, 0}, columns, rows)

	assert_clean(t, strings.to_string(buf), "narrow draw_table")
	free_all(context.temp_allocator)
}

@(test)
test_list_sanitizes_item_text :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_list(&buf, {0, 0}, []List_Item{{text = EVIL}}, -1)
	assert_clean(t, strings.to_string(buf), "draw_list")
	free_all(context.temp_allocator)
}

@(test)
test_scrollable_list_sanitizes_item_text :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_list_scrollable(&buf, {0, 0}, 2, []List_Item{{text = EVIL}}, 0, 0)
	assert_clean(t, strings.to_string(buf), "draw_list_scrollable")
	free_all(context.temp_allocator)
}

@(test)
test_tree_sanitizes_labels :: proc(t: ^testing.T) {
	node := make_tree_node(EVIL, .File)
	defer free(node)

	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_tree(&buf, {0, 0}, []^Tree_Node{node}, nil, default_tree_config())
	assert_clean(t, strings.to_string(buf), "draw_tree")
	free_all(context.temp_allocator)
}

@(test)
test_box_sanitizes_title :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_box_titled(&buf, {0, 0}, 30, 3, EVIL)
	assert_clean(t, strings.to_string(buf), "draw_box_titled")
	free_all(context.temp_allocator)
}

@(test)
test_input_sanitizes_text_and_placeholder :: proc(t: ^testing.T) {
	state := make_input_state(64, EVIL)
	defer destroy_input_state(&state)
	state.is_focused = true

	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Placeholder path (empty buffer)
	draw_input(&buf, {0, 0}, &state, 30, .Inline)
	assert_clean(t, strings.to_string(buf), "draw_input placeholder")

	// Text path
	for r in EVIL {
		input_add_char(&state, r)
	}
	strings.builder_reset(&buf)
	draw_input(&buf, {0, 0}, &state, 30, .Inline)
	assert_clean(t, strings.to_string(buf), "draw_input text")
	free_all(context.temp_allocator)
}

@(test)
test_sanitize_display_is_allocation_free_when_clean :: proc(t: ^testing.T) {
	// The render path calls this for every string a component draws.
	clean := "ordinary text 你好 123"
	out := munin.sanitize_display(clean)
	testing.expect(t, raw_data(out) == raw_data(clean), "should return the input unchanged")
}
