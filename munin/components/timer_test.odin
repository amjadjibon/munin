package components

import munin ".."
import "core:strings"
import "core:testing"
import "core:time"

// ============================================================
// TIMER COMPONENT
// ============================================================

@(private = "file")
render_timer :: proc(remaining: time.Duration, state: Timer_State, ms := false) -> string {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_timer(&buf, {0, 0}, remaining, state, ms)
	return strings.clone(munin.strip_ansi(strings.to_string(buf)), context.temp_allocator)
}

@(test)
test_timer_formats_hms :: proc(t: ^testing.T) {
	out := render_timer(90 * time.Second, .Running)
	testing.expect(t, strings.contains(out, "00:01:30"), "90s should render as 00:01:30")
	free_all(context.temp_allocator)
}

@(test)
test_timer_formats_hours :: proc(t: ^testing.T) {
	out := render_timer(3 * time.Hour + 25 * time.Minute + 7 * time.Second, .Running)
	testing.expect(t, strings.contains(out, "03:25:07"), "Should render hours")
	free_all(context.temp_allocator)
}

@(test)
test_timer_formats_milliseconds :: proc(t: ^testing.T) {
	out := render_timer(1500 * time.Millisecond, .Running, true)
	testing.expect(t, strings.contains(out, "00:00:01.500"), "Should render milliseconds")
	free_all(context.temp_allocator)
}

@(test)
test_timer_zero_duration :: proc(t: ^testing.T) {
	out := render_timer(0, .Finished)
	testing.expect(t, strings.contains(out, "00:00:00"), "Zero should render as 00:00:00")
	free_all(context.temp_allocator)
}

@(test)
test_timer_negative_duration_does_not_underflow :: proc(t: ^testing.T) {
	// An overrun timer must not print negative or wrapped components.
	out := render_timer(-5 * time.Second, .Finished)
	testing.expect(t, !strings.contains(out, "-"), "Should not render a negative time")

	with_ms := render_timer(-5500 * time.Millisecond, .Finished, true)
	testing.expect(t, !strings.contains(with_ms, "-"), "Milliseconds must be clamped too")
	testing.expect(t, strings.contains(with_ms, "00:00:00.000"), "Should floor at zero")
	free_all(context.temp_allocator)
}

@(test)
test_timer_states_have_labels :: proc(t: ^testing.T) {
	expected := [Timer_State]string {
		.Ready    = "Ready",
		.Running  = "Running",
		.Paused   = "Paused",
		.Finished = "Finished",
	}

	for state in Timer_State {
		out := render_timer(30 * time.Second, state)
		testing.expectf(
			t,
			strings.contains(out, expected[state]),
			"%v should show %q",
			state,
			expected[state],
		)
	}
	free_all(context.temp_allocator)
}

@(test)
test_timer_colors_by_urgency :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Under 10 seconds -> warning color
	draw_timer(&buf, {0, 0}, 5 * time.Second, .Running)
	testing.expect(t, strings.contains(strings.to_string(buf), "\x1b[93m"), "Warning color")

	// Expired -> red
	strings.builder_reset(&buf)
	draw_timer(&buf, {0, 0}, 0, .Finished)
	testing.expect(t, strings.contains(strings.to_string(buf), "\x1b[91m"), "Expired color")
	free_all(context.temp_allocator)
}

@(test)
test_timer_with_progress_renders_bar :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_timer_with_progress(&buf, {0, 0}, 30 * time.Second, 60 * time.Second, .Running, 10)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "00:00:30"), "Should show the time")
	testing.expect_value(t, strings.count(out, "█"), 5) // half elapsed
	free_all(context.temp_allocator)
}

@(test)
test_timer_with_progress_zero_total :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	// Must not divide by zero.
	draw_timer_with_progress(&buf, {0, 0}, 0, 0, .Ready, 10)
	testing.expect(t, strings.builder_len(buf) > 0, "Should render without crashing")
	free_all(context.temp_allocator)
}

@(test)
test_timer_boxed_renders_title_and_controls :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_timer_boxed(&buf, {0, 0}, 40, 10 * time.Second, 60 * time.Second, .Paused, "Pomodoro")
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "Pomodoro"), "Title")
	testing.expect(t, strings.contains(out, "Reset"), "Controls hint")
	free_all(context.temp_allocator)
}

@(test)
test_timer_presets :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_timer_presets(&buf, {0, 0}, {30, 60, 300}, 1)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "30s"), "Seconds preset")
	testing.expect(t, strings.contains(out, "1m"), "Minute preset")
	testing.expect(t, strings.contains(out, "5m"), "Five minute preset")
	free_all(context.temp_allocator)
}

@(test)
test_timer_presets_empty :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_timer_presets(&buf, {0, 0}, {})
	testing.expect(
		t,
		strings.contains(munin.strip_ansi(strings.to_string(buf)), "Quick Timers"),
		"Header still renders",
	)
	free_all(context.temp_allocator)
}
