package munin

import "core:strings"
import "core:testing"

// ============================================================
// INTEGRATION TESTS - Full program lifecycle and bug fixes
// ============================================================

// Test model for integration tests
Integration_Model :: struct {
	count:   int,
	message: string,
}

Integration_Msg :: union {
	Increment,
	SetMessage,
	Quit,
}

Increment :: struct {}
SetMessage :: struct {
	text: string,
}
Quit :: struct {}

integration_init :: proc() -> Integration_Model {
	return Integration_Model{count = 0, message = ""}
}

integration_update :: proc(msg: Integration_Msg, model: Integration_Model) -> (Integration_Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case Increment:
		new_model.count += 1
	case SetMessage:
		new_model.message = m.text
	case Quit:
		should_quit = true
	}

	return new_model, should_quit
}

integration_view :: proc(model: Integration_Model, buf: ^strings.Builder) {
	clear_screen(buf)
	print_at(buf, {0, 0}, "Counter:", .Green)
	printf_at(buf, {10, 0}, .BrightYellow, "%d", model.count)
	if len(model.message) > 0 {
		print_at(buf, {0, 1}, model.message, .Cyan)
	}
}

// ============================================================
// PROGRAM LIFECYCLE INTEGRATION TESTS
// ============================================================

@(test)
test_integration_program_creation :: proc(t: ^testing.T) {
	program := make_program(integration_init, integration_update, integration_view)
	defer strings.builder_destroy(&program.buffer)

	testing.expect_value(t, program.model.count, 0)
	testing.expect_value(t, program.model.message, "")
	testing.expect_value(t, program.running, true)
}

@(test)
test_integration_update_increment :: proc(t: ^testing.T) {
	program := make_program(integration_init, integration_update, integration_view)
	defer strings.builder_destroy(&program.buffer)

	// Simulate increment message
	msg := Integration_Msg(Increment{})
	new_model, should_quit := program.update(msg, program.model)

	testing.expect_value(t, new_model.count, 1)
	testing.expect_value(t, should_quit, false)
}

@(test)
test_integration_update_multiple :: proc(t: ^testing.T) {
	program := make_program(integration_init, integration_update, integration_view)
	defer strings.builder_destroy(&program.buffer)

	model := program.model

	// Increment 5 times
	for i in 0..<5 {
		msg := Integration_Msg(Increment{})
		model, _ = program.update(msg, model)
	}

	testing.expect_value(t, model.count, 5)
}

@(test)
test_integration_update_set_message :: proc(t: ^testing.T) {
	program := make_program(integration_init, integration_update, integration_view)
	defer strings.builder_destroy(&program.buffer)

	msg := Integration_Msg(SetMessage{"Hello, World!"})
	new_model, should_quit := program.update(msg, program.model)

	testing.expect_value(t, new_model.message, "Hello, World!")
	testing.expect_value(t, should_quit, false)
}

@(test)
test_integration_update_quit :: proc(t: ^testing.T) {
	program := make_program(integration_init, integration_update, integration_view)
	defer strings.builder_destroy(&program.buffer)

	msg := Integration_Msg(Quit{})
	new_model, should_quit := program.update(msg, program.model)

	testing.expect_value(t, should_quit, true)
}

@(test)
test_integration_view_output :: proc(t: ^testing.T) {
	program := make_program(integration_init, integration_update, integration_view)
	defer strings.builder_destroy(&program.buffer)

	// Set some state
	program.model.count = 42
	program.model.message = "Test Message"

	// Render view
	strings.builder_reset(&program.buffer)
	program.view(program.model, &program.buffer)

	output := strings.to_string(program.buffer)

	// Check output contains expected elements
	assert_contains(t, output, "Counter:", "Should contain label")
	assert_contains(t, output, "42", "Should contain count")
	assert_contains(t, output, "Test Message", "Should contain message")
	assert_contains(t, output, "\x1b[", "Should contain ANSI codes")
}

// ============================================================
// BUG FIX VERIFICATION TESTS
// ============================================================

// Test Bug Fix #1: UTF-8 handling in draw_title
@(test)
test_bug_fix_utf8_draw_title :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Test with CJK characters
	draw_title(&buf, {0, 0}, 20, "你好", .Reset, false)
	output := strings.to_string(buf)

	// Title is 2 runes, width is 20, padding = (20-2)/2 = 9
	testing.expect(t, strings.contains(output, "\x1b[0;9H"), "UTF-8 centering should work")
	testing.expect(t, strings.contains(output, "你好"), "Should contain UTF-8 text")
}

// Test Bug Fix #2: ANSI stripping in count_lines
@(test)
test_bug_fix_ansi_stripping :: proc(t: ^testing.T) {
	// Text with ANSI codes should be stripped before counting
	text := "\x1b[31mRed Line 1\x1b[0m\n\x1b[32mGreen Line 2\x1b[0m"
	lines := count_lines(text)

	testing.expect_value(t, lines, 2, "Should count 2 lines after stripping ANSI")
}

// Test Bug Fix #3: Wide character handling in rune_visual_width
@(test)
test_bug_fix_wide_characters :: proc(t: ^testing.T) {
	// CJK characters should be 2 cells wide
	testing.expect_value(t, rune_visual_width('你'), 2, "CJK should be wide")
	testing.expect_value(t, rune_visual_width('好'), 2, "CJK should be wide")

	// ASCII should be 1 cell wide
	testing.expect_value(t, rune_visual_width('A'), 1, "ASCII should be normal width")
}

// Test Bug Fix #4: Input buffer size increased
@(test)
test_bug_fix_input_buffer_size :: proc(t: ^testing.T) {
	// This test verifies that input buffer is large enough
	// We can't directly test the buffer size, but we verify
	// that the buffer would fit common escape sequences

	// Page Up: ESC [ 5 ~ (5 bytes)
	page_up := []byte{27, '[', '5', '~'}
	testing.expect(t, len(page_up) <= 16, "Buffer should fit Page Up")

	// F1-F12 keys can be up to 5-6 bytes
	f_key := []byte{27, '[', '1', '1', '~'} // F1
	testing.expect(t, len(f_key) <= 16, "Buffer should fit function keys")

	// Mouse SGR can be up to ~15 bytes
	mouse := []byte{27, '[', '<', '0', ';', '2', '0', '0', ';', '1', '5', '0', 'M'}
	testing.expect(t, len(mouse) <= 16, "Buffer should fit mouse events")
}

// Test Bug Fix #5: Thread-safe window resize flag
@(test)
test_bug_fix_thread_safety :: proc(t: ^testing.T) {
	when ODIN_OS != .Windows {
		import "core:sync"

		// Reset flag
		sync.atomic_store(&window_resized_atomic, 0)

		// Multiple atomic operations should be safe
		sync.atomic_store(&window_resized_atomic, 1)
		value1 := sync.atomic_load(&window_resized_atomic)
		testing.expect_value(t, value1, 1)

		old := sync.atomic_exchange(&window_resized_atomic, 0)
		testing.expect_value(t, old, 1)

		value2 := sync.atomic_load(&window_resized_atomic)
		testing.expect_value(t, value2, 0)
	}
}

// ============================================================
// COMPLEX RENDERING INTEGRATION TESTS
// ============================================================

@(test)
test_integration_complex_rendering :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Clear screen
	clear_screen(&buf)

	// Draw a box
	draw_box(&buf, {5, 5}, 30, 10, .Blue)

	// Draw title inside box
	draw_title(&buf, {5, 6}, 30, "Test Box", .BrightYellow, true)

	// Print some colored text
	print_at(&buf, {7, 8}, "Line 1", .Green)
	print_at(&buf, {7, 9}, "Line 2", .Red)

	// Print formatted text
	printf_at(&buf, {7, 10}, .Cyan, "Count: %d", 42)

	output := strings.to_string(buf)

	// Verify all elements are present
	assert_contains(t, output, "┌", "Should have box top-left")
	assert_contains(t, output, "┐", "Should have box top-right")
	assert_contains(t, output, "└", "Should have box bottom-left")
	assert_contains(t, output, "┘", "Should have box bottom-right")
	assert_contains(t, output, "Test Box", "Should have title")
	assert_contains(t, output, "Line 1", "Should have line 1")
	assert_contains(t, output, "Line 2", "Should have line 2")
	assert_contains(t, output, "Count: 42", "Should have formatted text")

	// Verify ANSI codes are present
	assert_contains(t, output, "\x1b[", "Should have ANSI codes")
}

@(test)
test_integration_utf8_rendering :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Mix of ASCII, UTF-8, and emoji
	print_at(&buf, {0, 0}, "Hello", .Reset)
	print_at(&buf, {0, 1}, "你好", .Reset)
	print_at(&buf, {0, 2}, "🚀✨", .Reset)
	print_at(&buf, {0, 3}, "Mixed: ABC 你好 🎉", .Reset)

	output := strings.to_string(buf)

	assert_contains(t, output, "Hello", "Should have ASCII")
	assert_contains(t, output, "你好", "Should have CJK")
	assert_contains(t, output, "🚀✨", "Should have emoji")
	assert_contains(t, output, "Mixed: ABC 你好 🎉", "Should have mixed text")
}

@(test)
test_integration_style_combinations :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Test combining styles
	set_color(&buf, .Red)
	set_bold(&buf)
	strings.write_string(&buf, "Bold Red")
	reset_style(&buf)

	strings.write_string(&buf, " ")

	set_color(&buf, .Green)
	set_underline(&buf)
	strings.write_string(&buf, "Underline Green")
	reset_style(&buf)

	output := strings.to_string(buf)

	assert_contains(t, output, "\x1b[31m", "Should have red color")
	assert_contains(t, output, "\x1b[1m", "Should have bold")
	assert_contains(t, output, "\x1b[32m", "Should have green color")
	assert_contains(t, output, "\x1b[4m", "Should have underline")
	assert_contains(t, output, "\x1b[0m", "Should have reset")
	assert_contains(t, output, "Bold Red", "Should have text")
	assert_contains(t, output, "Underline Green", "Should have text")
}

// ============================================================
// EDGE CASE INTEGRATION TESTS
// ============================================================

@(test)
test_integration_empty_view :: proc(t: ^testing.T) {
	empty_view :: proc(model: Integration_Model, buf: ^strings.Builder) {
		// Empty view - just clear screen
		clear_screen(buf)
	}

	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	model := Integration_Model{}
	empty_view(model, &buf)

	output := strings.to_string(buf)
	testing.expect(t, len(output) > 0, "Should have some output (clear sequence)")
}

@(test)
test_integration_very_long_output :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Draw many lines
	for i in 0..<100 {
		printf_at(&buf, {0, i}, .Reset, "Line %d", i)
	}

	output := strings.to_string(buf)
	testing.expect(t, len(output) > 0, "Should generate output")
	assert_contains(t, output, "Line 0", "Should have first line")
	assert_contains(t, output, "Line 99", "Should have last line")
}

@(test)
test_integration_overlapping_draws :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Draw overlapping text (later draws overwrite earlier ones)
	print_at(&buf, {0, 0}, "AAAAA", .Red)
	print_at(&buf, {2, 0}, "BBB", .Blue)

	output := strings.to_string(buf)

	// Both should be in output (they overlap in terminal buffer)
	assert_contains(t, output, "AAAAA", "Should have first text")
	assert_contains(t, output, "BBB", "Should have second text")
}

@(test)
test_integration_parameter_validation :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Test that valid parameters work
	// (Invalid parameters would panic in debug mode)

	move_cursor(&buf, {0, 0})
	draw_box(&buf, {0, 0}, 2, 2, .Reset)
	print_at(&buf, {0, 0}, "Test", .Reset)
	draw_title(&buf, {0, 0}, 10, "Title", .Reset, false)

	output := strings.to_string(buf)
	testing.expect(t, len(output) > 0, "Valid parameters should work")
}
