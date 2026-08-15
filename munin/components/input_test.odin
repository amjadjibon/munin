package components

import "core:strings"
import "core:testing"

@(test)
test_input_cursor_moves_by_utf8_rune :: proc(t: ^testing.T) {
	state := make_input_state(32)
	defer destroy_input_state(&state)

	input_add_char(&state, 'a')
	input_add_char(&state, '好')
	input_add_char(&state, 'b')

	testing.expect_value(t, input_get_text(&state), "a好b")
	testing.expect_value(t, state.cursor_pos, 5)

	input_cursor_left(&state)
	testing.expect_value(t, state.cursor_pos, 4)

	input_cursor_left(&state)
	testing.expect_value(t, state.cursor_pos, 1)

	input_cursor_right(&state)
	testing.expect_value(t, state.cursor_pos, 4)
}

@(test)
test_input_backspace_removes_whole_utf8_rune :: proc(t: ^testing.T) {
	state := make_input_state(32)
	defer destroy_input_state(&state)

	input_add_char(&state, 'a')
	input_add_char(&state, '好')
	input_add_char(&state, 'b')

	input_cursor_left(&state)
	input_backspace(&state)

	testing.expect_value(t, input_get_text(&state), "ab")
	testing.expect_value(t, state.cursor_pos, 1)
}

@(test)
test_input_delete_removes_whole_utf8_rune :: proc(t: ^testing.T) {
	state := make_input_state(32)
	defer destroy_input_state(&state)

	input_add_char(&state, 'a')
	input_add_char(&state, '好')
	input_add_char(&state, 'b')

	input_cursor_home(&state)
	input_cursor_right(&state)
	input_delete(&state)

	testing.expect_value(t, input_get_text(&state), "ab")
	testing.expect_value(t, state.cursor_pos, 1)
}

@(test)
test_input_add_char_respects_max_length_by_encoded_size :: proc(t: ^testing.T) {
	state := make_input_state(3)
	defer destroy_input_state(&state)

	input_add_char(&state, 'a')
	input_add_char(&state, '😀')

	testing.expect_value(t, input_get_text(&state), "a")
	testing.expect_value(t, state.cursor_pos, 1)

	input_clear(&state)
	input_add_char(&state, '好')
	input_add_char(&state, 'x')

	testing.expect_value(t, input_get_text(&state), "好")
	testing.expect_value(t, state.cursor_pos, 3)
}

// ============================================================
// RENDERING SAFETY (REGRESSION)
// ============================================================

@(test)
test_draw_input_password_no_leak :: proc(t: ^testing.T) {
	// The mask string used to be allocated from context.allocator on every
	// frame and never freed. The test runner's tracking allocator fails this
	// test if that regresses.
	state := make_input_state(32, "")
	defer destroy_input_state(&state)
	state.is_password = true
	state.is_focused = true
	input_add_char(&state, 'h')
	input_add_char(&state, 'i')

	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	for _ in 0 ..< 10 {
		draw_input(&buf, {0, 0}, &state, 20)
	}

	free_all(context.temp_allocator)
	testing.expect(t, strings.builder_len(buf) > 0, "Should render something")
}

@(test)
test_draw_input_masks_by_character_not_byte :: proc(t: ^testing.T) {
	state := make_input_state(32, "")
	defer destroy_input_state(&state)
	state.is_password = true
	input_add_char(&state, 'é') // 2 bytes, 1 character

	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)
	draw_input(&buf, {0, 0}, &state, 20, .Inline)
	free_all(context.temp_allocator)

	testing.expect_value(t, strings.count(strings.to_string(buf), "*"), 1)
}

@(test)
test_draw_input_tiny_width_does_not_crash :: proc(t: ^testing.T) {
	// draw_input passes width-2 to the content renderer, which used to slice
	// with a negative bound.
	state := make_input_state(32, "placeholder text")
	defer destroy_input_state(&state)
	state.is_focused = true

	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	for w in 0 ..< 4 {
		draw_input(&buf, {0, 0}, &state, w)
		input_add_char(&state, 'x')
		draw_input(&buf, {0, 0}, &state, w)
	}
	free_all(context.temp_allocator)
}

@(test)
test_draw_input_multibyte_cursor :: proc(t: ^testing.T) {
	state := make_input_state(32, "")
	defer destroy_input_state(&state)
	state.is_focused = true
	state.cursor_blink_state = false
	input_add_char(&state, '你')
	input_add_char(&state, '好')
	input_cursor_home(&state)

	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)
	draw_input(&buf, {0, 0}, &state, 20, .Inline)
	free_all(context.temp_allocator)

	// With the cursor "off" the real characters are drawn whole, not sliced
	// one byte at a time.
	testing.expect(t, strings.contains(strings.to_string(buf), "你好"), "Should render intact text")
}

@(test)
test_input_get_text_returns_a_view_not_a_copy :: proc(t: ^testing.T) {
	// Pins the documented contract: the result aliases the input's buffer, so
	// it is only valid until the next edit. Storing it across one is the bug
	// that put aliased messages into the forms example's chat history.
	state := make_input_state(32, "")
	defer destroy_input_state(&state)

	for r in "hello" {
		input_add_char(&state, r)
	}
	borrowed := input_get_text(&state)
	testing.expect_value(t, borrowed, "hello")

	input_clear(&state)
	for r in "world" {
		input_add_char(&state, r)
	}

	testing.expect_value(t, borrowed, "world") // same bytes, new content
}

@(test)
test_input_clone_text_survives_later_edits :: proc(t: ^testing.T) {
	state := make_input_state(32, "")
	defer destroy_input_state(&state)

	for r in "hello" {
		input_add_char(&state, r)
	}
	owned := input_clone_text(&state)
	defer delete(owned)

	input_clear(&state)
	for r in "world" {
		input_add_char(&state, r)
	}

	testing.expect_value(t, owned, "hello")
}
