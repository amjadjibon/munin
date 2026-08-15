package components

import munin ".."
import "core:strings"
import "core:testing"

// ============================================================
// SPINNER COMPONENT
// ============================================================

@(test)
test_spinner_frame_count_matches_tables :: proc(t: ^testing.T) {
	testing.expect_value(t, get_spinner_frame_count(.Dots), len(SPINNER_FRAMES_DOTS))
	testing.expect_value(t, get_spinner_frame_count(.Line), len(SPINNER_FRAMES_LINE))
	testing.expect_value(t, get_spinner_frame_count(.Arrow), len(SPINNER_FRAMES_ARROW))
	testing.expect_value(t, get_spinner_frame_count(.Circle), len(SPINNER_FRAMES_CIRCLE))
	testing.expect_value(t, get_spinner_frame_count(.Box), len(SPINNER_FRAMES_BOX))
	testing.expect_value(t, get_spinner_frame_count(.Star), len(SPINNER_FRAMES_STAR))
	testing.expect_value(t, get_spinner_frame_count(.Moon), len(SPINNER_FRAMES_MOON))
	testing.expect_value(t, get_spinner_frame_count(.Clock), len(SPINNER_FRAMES_CLOCK))
}

@(test)
test_calculate_frame_index_forward :: proc(t: ^testing.T) {
	testing.expect_value(t, calculate_frame_index(0, 4, .Forward), 0)
	testing.expect_value(t, calculate_frame_index(3, 4, .Forward), 3)
	testing.expect_value(t, calculate_frame_index(4, 4, .Forward), 0)
	testing.expect_value(t, calculate_frame_index(9, 4, .Forward), 1)
}

@(test)
test_calculate_frame_index_reverse :: proc(t: ^testing.T) {
	testing.expect_value(t, calculate_frame_index(0, 4, .Reverse), 0)
	testing.expect_value(t, calculate_frame_index(1, 4, .Reverse), 3)
	testing.expect_value(t, calculate_frame_index(2, 4, .Reverse), 2)
	testing.expect_value(t, calculate_frame_index(4, 4, .Reverse), 0)
}

@(test)
test_calculate_frame_index_negative_frame :: proc(t: ^testing.T) {
	// Regression: Odin's % keeps the sign of the dividend, so a negative
	// frame counter indexed before the start of the frame array.
	for frame in -20 ..= -1 {
		for count in ([]int{4, 6, 8, 12}) {
			idx := calculate_frame_index(frame, count, .Forward)
			testing.expectf(t, idx >= 0 && idx < count, "Forward index %d out of range", idx)

			rev := calculate_frame_index(frame, count, .Reverse)
			testing.expectf(t, rev >= 0 && rev < count, "Reverse index %d out of range", rev)
		}
	}
}

@(test)
test_calculate_frame_index_zero_count :: proc(t: ^testing.T) {
	testing.expect_value(t, calculate_frame_index(5, 0, .Forward), 0)
	testing.expect_value(t, calculate_frame_index(5, 0, .Reverse), 0)
}

@(test)
test_calculate_frame_index_always_in_range :: proc(t: ^testing.T) {
	for style in Spinner_Style {
		count := get_spinner_frame_count(style)
		for frame in 0 ..< 100 {
			idx := calculate_frame_index(frame, count, .Forward)
			testing.expectf(t, idx >= 0 && idx < count, "%v index %d out of range", style, idx)
		}
	}
}

@(test)
test_draw_spinner_all_styles :: proc(t: ^testing.T) {
	for style in Spinner_Style {
		buf := strings.builder_make()
		defer strings.builder_destroy(&buf)

		draw_spinner(&buf, {0, 0}, 3, style)
		out := munin.strip_ansi(strings.to_string(buf))
		testing.expectf(t, len(out) > 0, "%v should draw a frame", style)
	}
}

@(test)
test_draw_spinner_advances_between_frames :: proc(t: ^testing.T) {
	frames: [4]string
	for i in 0 ..< 4 {
		buf := strings.builder_make()
		defer strings.builder_destroy(&buf)

		draw_spinner(&buf, {0, 0}, i, .Line)
		frames[i] = strings.clone(
			munin.strip_ansi(strings.to_string(buf)),
			context.temp_allocator,
		)
	}

	testing.expect(t, frames[0] != frames[1], "Consecutive frames should differ")
	free_all(context.temp_allocator)
}

@(test)
test_draw_spinner_with_label :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_spinner(&buf, {0, 0}, 0, .Dots, munin.Basic_Color.BrightCyan, "Loading...")
	testing.expect(
		t,
		strings.contains(munin.strip_ansi(strings.to_string(buf)), "Loading..."),
		"Label should be drawn",
	)
}

@(test)
test_draw_spinner_negative_frame_does_not_crash :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	for style in Spinner_Style {
		draw_spinner(&buf, {0, 0}, -7, style)
	}
	testing.expect(t, strings.builder_len(buf) > 0, "Should render without crashing")
}
