package munin

import "core:strings"
import "core:testing"

// ============================================================
// MUNIN CORE TESTS - Line counting, ANSI stripping, etc.
// ============================================================

@(test)
test_strip_ansi_no_codes :: proc(t: ^testing.T) {
	input := "Hello World"
	output := strip_ansi(input)
	testing.expect_value(t, output, "Hello World")
}

@(test)
test_strip_ansi_simple_color :: proc(t: ^testing.T) {
	input := "\x1b[31mRed Text\x1b[0m"
	output := strip_ansi(input)
	testing.expect_value(t, output, "Red Text")
}

@(test)
test_strip_ansi_multiple_codes :: proc(t: ^testing.T) {
	input := "\x1b[1m\x1b[31mBold Red\x1b[0m Normal \x1b[32mGreen\x1b[0m"
	output := strip_ansi(input)
	testing.expect_value(t, output, "Bold Red Normal Green")
}

@(test)
test_strip_ansi_cursor_movement :: proc(t: ^testing.T) {
	input := "\x1b[10;20HText at position"
	output := strip_ansi(input)
	testing.expect_value(t, output, "Text at position")
}

@(test)
test_strip_ansi_clear_sequences :: proc(t: ^testing.T) {
	input := "\x1b[2J\x1b[HCleared screen"
	output := strip_ansi(input)
	testing.expect_value(t, output, "Cleared screen")
}

@(test)
test_strip_ansi_osc_sequences :: proc(t: ^testing.T) {
	// OSC sequence with BEL terminator
	input := "\x1b]0;Window Title\x07Content"
	output := strip_ansi(input)
	testing.expect_value(t, output, "Content")
}

@(test)
test_strip_ansi_osc_st_terminator :: proc(t: ^testing.T) {
	// OSC sequence with ST terminator (ESC \)
	input := "\x1b]0;Title\x1b\\Text"
	output := strip_ansi(input)
	testing.expect_value(t, output, "Text")
}

@(test)
test_strip_ansi_complex :: proc(t: ^testing.T) {
	// Mix of everything
	input := "\x1b[H\x1b[2J\x1b[1;32mGreen\x1b[0m \x1b[1;31mRed\x1b[0m"
	output := strip_ansi(input)
	testing.expect_value(t, output, "Green Red")
}

@(test)
test_strip_ansi_empty :: proc(t: ^testing.T) {
	input := ""
	output := strip_ansi(input)
	testing.expect_value(t, output, "")
}

@(test)
test_strip_ansi_only_codes :: proc(t: ^testing.T) {
	input := "\x1b[31m\x1b[1m\x1b[0m"
	output := strip_ansi(input)
	testing.expect_value(t, output, "")
}

// ============================================================
// RUNE VISUAL WIDTH TESTS
// ============================================================

@(test)
test_rune_visual_width_ascii :: proc(t: ^testing.T) {
	testing.expect_value(t, rune_visual_width('A'), 1)
	testing.expect_value(t, rune_visual_width('z'), 1)
	testing.expect_value(t, rune_visual_width('0'), 1)
	testing.expect_value(t, rune_visual_width(' '), 1)
	testing.expect_value(t, rune_visual_width('!'), 1)
}

@(test)
test_rune_visual_width_control_chars :: proc(t: ^testing.T) {
	testing.expect_value(t, rune_visual_width('\n'), 0)
	testing.expect_value(t, rune_visual_width('\t'), 0)
	testing.expect_value(t, rune_visual_width('\r'), 0)
	testing.expect_value(t, rune_visual_width(0x00), 0)
	testing.expect_value(t, rune_visual_width(0x1F), 0)
}

@(test)
test_rune_visual_width_cjk :: proc(t: ^testing.T) {
	// Chinese characters
	testing.expect_value(t, rune_visual_width('你'), 2)
	testing.expect_value(t, rune_visual_width('好'), 2)
	testing.expect_value(t, rune_visual_width('世'), 2)

	// Japanese Hiragana
	testing.expect_value(t, rune_visual_width('あ'), 2)
	testing.expect_value(t, rune_visual_width('か'), 2)

	// Japanese Katakana
	testing.expect_value(t, rune_visual_width('ア'), 2)
	testing.expect_value(t, rune_visual_width('カ'), 2)

	// Korean Hangul
	testing.expect_value(t, rune_visual_width('안'), 2)
	testing.expect_value(t, rune_visual_width('녕'), 2)
}

@(test)
test_rune_visual_width_fullwidth :: proc(t: ^testing.T) {
	// Fullwidth ASCII variants
	testing.expect_value(t, rune_visual_width('Ａ'), 2)
	testing.expect_value(t, rune_visual_width('０'), 2)
}

// ============================================================
// COUNT LINES TESTS
// ============================================================

@(test)
test_count_lines_empty :: proc(t: ^testing.T) {
	testing.expect_value(t, count_lines(""), 0)
}

@(test)
test_count_lines_single_line :: proc(t: ^testing.T) {
	testing.expect_value(t, count_lines("Hello"), 1)
	testing.expect_value(t, count_lines("Single line text"), 1)
}

@(test)
test_count_lines_with_newlines :: proc(t: ^testing.T) {
	testing.expect_value(t, count_lines("Line 1\nLine 2"), 2)
	testing.expect_value(t, count_lines("Line 1\nLine 2\nLine 3"), 3)
}

@(test)
test_count_lines_trailing_newline :: proc(t: ^testing.T) {
	testing.expect_value(t, count_lines("Line 1\n"), 1)
	testing.expect_value(t, count_lines("Line 1\nLine 2\n"), 2)
}

@(test)
test_count_lines_with_ansi :: proc(t: ^testing.T) {
	// ANSI codes should be stripped before counting
	input := "\x1b[31mRed\x1b[0m"
	// "Red" = 3 chars, fits in one line
	testing.expect_value(t, count_lines(input), 1)
}

@(test)
test_count_lines_ansi_multiline :: proc(t: ^testing.T) {
	input := "\x1b[31mLine 1\x1b[0m\n\x1b[32mLine 2\x1b[0m"
	testing.expect_value(t, count_lines(input), 2)
}

@(test)
test_count_lines_wrapping :: proc(t: ^testing.T) {
	// This test depends on terminal width
	// We can't control get_window_size() in tests, so this is a basic check
	// In a real terminal with 80 columns, a line of 100 chars would wrap

	// Short line - should be 1
	short := strings.repeat("a", 10)
	defer delete(short)
	testing.expect_value(t, count_lines(short), 1)
}

@(test)
test_count_lines_cjk_characters :: proc(t: ^testing.T) {
	// CJK characters are wide (2 cells each)
	// "你好世" = 3 characters × 2 cells = 6 cells
	input := "你好世"
	// Should be 1 line (fits in most terminals)
	testing.expect_value(t, count_lines(input), 1)
}

@(test)
test_count_lines_mixed_content :: proc(t: ^testing.T) {
	// Mix of ASCII, ANSI, and newlines
	input := "\x1b[31mRed\x1b[0m\nNormal\n\x1b[32mGreen\x1b[0m"
	testing.expect_value(t, count_lines(input), 3)
}

// ============================================================
// PROGRAM CREATION TESTS
// ============================================================

Model :: struct {
	counter: int,
}

Msg :: union {
	int,
}

test_init :: proc() -> Model {
	return Model{counter = 0}
}

test_update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	switch m in msg {
	case int:
		new_model.counter = m
	}
	return new_model, false
}

test_view :: proc(model: Model, buf: ^strings.Builder) {
	print_at(buf, {0, 0}, "Test", .Reset)
}

@(test)
test_make_program_without_subs :: proc(t: ^testing.T) {
	program := make_program(test_init, test_update, test_view)
	defer strings.builder_destroy(&program.buffer)

	testing.expect_value(t, program.running, true)
	testing.expect_value(t, program.screen_mode, Screen_Mode.Fullscreen)
	testing.expect_value(t, program.model.counter, 0)
	testing.expect(t, program.subscriptions == nil, "Should have no subscriptions")
}

test_subscriptions :: proc(model: Model) -> Maybe(Msg) {
	if model.counter < 10 {
		return Msg(model.counter + 1)
	}
	return nil
}

@(test)
test_make_program_with_subs :: proc(t: ^testing.T) {
	program := make_program(test_init, test_update, test_view, test_subscriptions)
	defer strings.builder_destroy(&program.buffer)

	testing.expect_value(t, program.running, true)
	testing.expect(t, program.subscriptions != nil, "Should have subscriptions")

	// Test subscription
	if sub, ok := program.subscriptions.?; ok {
		msg, has_msg := sub(program.model).?
		testing.expect(t, has_msg, "Should have subscription message")
		if has_msg {
			switch m in msg {
			case int:
				testing.expect_value(t, m, 1)
			}
		}
	}
}

@(test)
test_screen_mode_toggle :: proc(t: ^testing.T) {
	program := make_program(test_init, test_update, test_view)
	defer strings.builder_destroy(&program.buffer)

	// Initial mode
	testing.expect_value(t, program.screen_mode, Screen_Mode.Fullscreen)

	// Note: We can't actually test toggle_screen_mode without a real terminal
	// because it prints to stdout. We just verify the program was created correctly.
}

@(test)
test_set_screen_mode_same :: proc(t: ^testing.T) {
	program := make_program(test_init, test_update, test_view)
	defer strings.builder_destroy(&program.buffer)

	// Setting to same mode should be no-op
	// We can't fully test this without terminal, but verify initial state
	testing.expect_value(t, program.screen_mode, Screen_Mode.Fullscreen)
}

// ============================================================
// EDGE CASES AND BOUNDARY TESTS
// ============================================================

@(test)
test_strip_ansi_partial_sequences :: proc(t: ^testing.T) {
	// Incomplete escape sequence at end
	input := "Text\x1b["
	output := strip_ansi(input)
	// Should handle gracefully (consume the ESC [ but no more)
	testing.expect(t, len(output) >= 4, "Should preserve 'Text'")
}

@(test)
test_count_lines_only_newlines :: proc(t: ^testing.T) {
	testing.expect_value(t, count_lines("\n"), 1)
	testing.expect_value(t, count_lines("\n\n"), 2)
	testing.expect_value(t, count_lines("\n\n\n"), 3)
}

@(test)
test_rune_visual_width_del :: proc(t: ^testing.T) {
	// DEL character (0x7F)
	testing.expect_value(t, rune_visual_width(0x7F), 0)
}

@(test)
test_rune_visual_width_high_control :: proc(t: ^testing.T) {
	// High control characters
	testing.expect_value(t, rune_visual_width(0x80), 0)
	testing.expect_value(t, rune_visual_width(0x9F), 0)
}

@(test)
test_count_lines_very_long_line :: proc(t: ^testing.T) {
	// Very long line should wrap
	long := strings.repeat("x", 200)
	defer delete(long)

	lines := count_lines(long)
	// Should be > 1 if terminal is normal width (e.g., 80 cols -> ~3 lines)
	// We can't guarantee exact value without knowing terminal size
	testing.expect(t, lines >= 1, "Should count at least 1 line")
}
