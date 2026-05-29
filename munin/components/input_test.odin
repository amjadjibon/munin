package components

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
