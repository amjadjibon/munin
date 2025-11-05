package munin

import "core:strings"
import "core:testing"

// ============================================================
// UTILS TESTS - Drawing and Rendering Functions
// ============================================================

@(test)
test_move_cursor :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Test basic cursor movement
	move_cursor(&buf, {10, 5})
	output := strings.to_string(buf)

	testing.expect(t, strings.contains(output, "\x1b[5;10H"), "Should contain cursor move sequence")
}

@(test)
test_move_cursor_origin :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Test moving to origin
	move_cursor(&buf, {0, 0})
	output := strings.to_string(buf)

	testing.expect(t, strings.contains(output, "\x1b[0;0H"), "Should move to origin")
}

@(test)
test_clear_screen :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	clear_screen(&buf)
	output := strings.to_string(buf)

	testing.expect(t, strings.contains(output, "\x1b[H"), "Should contain home sequence")
	testing.expect(t, strings.contains(output, "\x1b[J"), "Should contain clear sequence")
}

@(test)
test_hide_show_cursor :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	hide_cursor(&buf)
	output1 := strings.to_string(buf)
	testing.expect(t, strings.contains(output1, "\x1b[?25l"), "Should hide cursor")

	strings.builder_reset(&buf)
	show_cursor(&buf)
	output2 := strings.to_string(buf)
	testing.expect(t, strings.contains(output2, "\x1b[?25h"), "Should show cursor")
}

@(test)
test_set_color :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	set_color(&buf, .Red)
	output := strings.to_string(buf)

	testing.expect(t, strings.contains(output, "\x1b[31m"), "Should set red color")
}

@(test)
test_set_bg_color :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	set_bg_color(&buf, .Blue)
	output := strings.to_string(buf)

	testing.expect(t, strings.contains(output, "\x1b[44m"), "Should set blue background")
}

@(test)
test_text_styles :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	set_bold(&buf)
	testing.expect(t, strings.contains(strings.to_string(buf), "\x1b[1m"), "Should set bold")

	strings.builder_reset(&buf)
	set_dim(&buf)
	testing.expect(t, strings.contains(strings.to_string(buf), "\x1b[2m"), "Should set dim")

	strings.builder_reset(&buf)
	set_underline(&buf)
	testing.expect(t, strings.contains(strings.to_string(buf), "\x1b[4m"), "Should set underline")

	strings.builder_reset(&buf)
	set_blink(&buf)
	testing.expect(t, strings.contains(strings.to_string(buf), "\x1b[5m"), "Should set blink")

	strings.builder_reset(&buf)
	set_reverse(&buf)
	testing.expect(t, strings.contains(strings.to_string(buf), "\x1b[7m"), "Should set reverse")

	strings.builder_reset(&buf)
	reset_style(&buf)
	testing.expect(t, strings.contains(strings.to_string(buf), "\x1b[0m"), "Should reset style")
}

@(test)
test_draw_box_basic :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_box(&buf, {0, 0}, 5, 3, .Reset)
	output := strings.to_string(buf)

	// Check for box characters
	testing.expect(t, strings.contains(output, "┌"), "Should have top-left corner")
	testing.expect(t, strings.contains(output, "┐"), "Should have top-right corner")
	testing.expect(t, strings.contains(output, "└"), "Should have bottom-left corner")
	testing.expect(t, strings.contains(output, "┘"), "Should have bottom-right corner")
	testing.expect(t, strings.contains(output, "─"), "Should have horizontal lines")
	testing.expect(t, strings.contains(output, "│"), "Should have vertical lines")
}

@(test)
test_draw_box_dimensions :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Test minimum valid box
	draw_box(&buf, {0, 0}, 2, 2, .Reset)
	output := strings.to_string(buf)

	// Should have all 4 corners
	assert_contains(t, output, "┌", "Minimum box should have top-left")
	assert_contains(t, output, "┐", "Minimum box should have top-right")
	assert_contains(t, output, "└", "Minimum box should have bottom-left")
	assert_contains(t, output, "┘", "Minimum box should have bottom-right")
}

@(test)
test_print_at :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	print_at(&buf, {5, 10}, "Hello", .Green)
	output := strings.to_string(buf)

	// Should contain cursor movement
	testing.expect(t, strings.contains(output, "\x1b[10;5H"), "Should move cursor")
	// Should contain text
	testing.expect(t, strings.contains(output, "Hello"), "Should contain text")
	// Should contain color
	testing.expect(t, strings.contains(output, "\x1b[32m"), "Should set green color")
	// Should reset style
	testing.expect(t, strings.contains(output, "\x1b[0m"), "Should reset style")
}

@(test)
test_print_at_no_color :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	print_at(&buf, {0, 0}, "Test", .Reset)
	output := strings.to_string(buf)

	testing.expect(t, strings.contains(output, "Test"), "Should contain text")
	// Should not have color codes (only cursor movement)
	visible := extract_visible_text(output)
	testing.expect_value(t, visible, "Test")
}

@(test)
test_printf_at :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	printf_at(&buf, {1, 1}, .Yellow, "Count: %d", 42)
	output := strings.to_string(buf)

	testing.expect(t, strings.contains(output, "Count: 42"), "Should format text")
	testing.expect(t, strings.contains(output, "\x1b[33m"), "Should set yellow color")
}

@(test)
test_draw_title_ascii :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// ASCII text should be centered correctly
	draw_title(&buf, {0, 0}, 20, "Hello", .Reset, false)
	output := strings.to_string(buf)

	// Title is 5 chars, width is 20, so padding = (20-5)/2 = 7.5 = 7
	// Cursor should be at x=7
	testing.expect(t, strings.contains(output, "\x1b[0;7H"), "Should center ASCII text correctly")
	testing.expect(t, strings.contains(output, "Hello"), "Should contain title text")
}

@(test)
test_draw_title_utf8 :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// UTF-8 text with 3 characters (你好世)
	// Each is 3 bytes but counts as 1 rune
	draw_title(&buf, {0, 0}, 20, "你好世", .Reset, false)
	output := strings.to_string(buf)

	// Title is 3 runes, width is 20, so padding = (20-3)/2 = 8.5 = 8
	// Cursor should be at x=8
	testing.expect(t, strings.contains(output, "\x1b[0;8H"), "Should center UTF-8 text by rune count")
	testing.expect(t, strings.contains(output, "你好世"), "Should contain UTF-8 text")
}

@(test)
test_draw_title_emoji :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Emoji (4 runes: 🚀🎉✨🌟)
	draw_title(&buf, {0, 0}, 20, "🚀🎉✨🌟", .Reset, false)
	output := strings.to_string(buf)

	// Title is 4 runes, width is 20, padding = (20-4)/2 = 8
	testing.expect(t, strings.contains(output, "\x1b[0;8H"), "Should center emoji by rune count")
}

@(test)
test_draw_title_mixed :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Mixed: ASCII + UTF-8 + emoji
	// "Hello 你好 🚀" = 5 + 1 + 2 + 1 + 1 = 10 runes
	draw_title(&buf, {0, 0}, 30, "Hello 你好 🚀", .Reset, false)
	output := strings.to_string(buf)

	// Padding = (30-10)/2 = 10
	testing.expect(t, strings.contains(output, "\x1b[0;10H"), "Should center mixed text correctly")
}

@(test)
test_draw_title_bold :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_title(&buf, {0, 0}, 10, "Bold", .Red, true)
	output := strings.to_string(buf)

	testing.expect(t, strings.contains(output, "\x1b[1m"), "Should have bold style")
	testing.expect(t, strings.contains(output, "\x1b[31m"), "Should have red color")
	testing.expect(t, strings.contains(output, "\x1b[0m"), "Should reset style")
}

@(test)
test_draw_title_overflow :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Title longer than width
	draw_title(&buf, {0, 0}, 5, "Very Long Title", .Reset, false)
	output := strings.to_string(buf)

	// Padding should be 0 (clamped), cursor at x=0
	testing.expect(t, strings.contains(output, "\x1b[0;0H"), "Should clamp negative padding to 0")
	testing.expect(t, strings.contains(output, "Very Long Title"), "Should still contain full text")
}

@(test)
test_set_window_title :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	set_window_title(&buf, "My App")
	output := strings.to_string(buf)

	// OSC 0 sequence
	testing.expect(t, strings.contains(output, "\x1b]0;My App\x07"), "Should set window title")
}

// ============================================================
// PARAMETER VALIDATION TESTS
// ============================================================

@(test)
test_draw_box_validation :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// These should panic in debug mode due to assertions
	// In release mode, they won't panic but will produce invalid output
	// We just test that valid inputs work

	// Valid: minimum size
	draw_box(&buf, {0, 0}, 2, 2, .Reset)
	testing.expect(t, len(strings.to_string(buf)) > 0, "Should draw 2x2 box")

	strings.builder_reset(&buf)

	// Valid: large box
	draw_box(&buf, {10, 10}, 50, 30, .Red)
	testing.expect(t, len(strings.to_string(buf)) > 0, "Should draw large box")
}

@(test)
test_print_at_validation :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Valid positions
	print_at(&buf, {0, 0}, "Origin", .Reset)
	testing.expect(t, strings.contains(strings.to_string(buf), "Origin"), "Should print at origin")

	strings.builder_reset(&buf)
	print_at(&buf, {100, 50}, "Far", .Reset)
	testing.expect(t, strings.contains(strings.to_string(buf), "Far"), "Should print at large coords")
}
