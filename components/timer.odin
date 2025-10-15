package components

import munin "../munin"
import "core:fmt"
import "core:strings"
import "core:time"

// ============================================================
// COUNTDOWN TIMER COMPONENT
// ============================================================

Timer_State :: enum {
	Ready,
	Running,
	Paused,
	Finished,
}

// Draw a countdown timer
draw_timer :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	remaining: time.Duration,
	state: Timer_State,
	show_milliseconds: bool = false,
	label_color: munin.Color = .BrightYellow,
	time_color: munin.Color = .BrightGreen,
) {
	// Calculate time components
	total_ms := i64(time.duration_milliseconds(remaining))
	total_seconds := max(total_ms / 1000, 0)
	milliseconds := total_ms % 1000
	seconds := total_seconds % 60
	minutes := (total_seconds / 60) % 60
	hours := total_seconds / 3600

	// Format time string
	time_str := ""
	if show_milliseconds {
		time_str = fmt.tprintf("%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
	} else {
		time_str = fmt.tprintf("%02d:%02d:%02d", hours, minutes, seconds)
	}

	// Choose color based on remaining time
	display_color := time_color
	if remaining <= 0 {
		display_color = .BrightRed
	} else if total_seconds < 10 {
		display_color = .BrightYellow
	}

	// Draw time
	munin.set_bold(buf)
	munin.print_at(buf, pos, time_str, display_color)
	munin.reset_style(buf)

	// Draw state indicator
	state_text := ""
	state_color := munin.Color.White
	switch state {
	case .Ready:
		state_text = "⏸ Ready"
		state_color = .BrightBlue
	case .Running:
		state_text = "▶ Running"
		state_color = .BrightGreen
	case .Paused:
		state_text = "⏸ Paused"
		state_color = .BrightYellow
	case .Finished:
		state_text = "✓ Finished"
		state_color = .BrightRed
	}

	munin.print_at(buf, {pos.x + len(time_str) + 2, pos.y}, state_text, state_color)
}

// Draw timer with circular progress indicator
draw_timer_with_progress :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	remaining: time.Duration,
	total: time.Duration,
	state: Timer_State,
	width: int = 40,
) {
	// Draw timer time
	draw_timer(buf, pos, remaining, state, false, .BrightYellow, .BrightGreen)

	// Calculate progress percentage
	progress := 0
	if total > 0 {
		elapsed := total - remaining
		progress = int((time.duration_seconds(elapsed) / time.duration_seconds(total)) * 100)
		progress = clamp(progress, 0, 100)
	}

	// Draw progress bar below timer
	draw_progress_bar(buf, {pos.x, pos.y + 2}, width, progress, .Blocks, .BrightCyan, .White, true)
}

// Draw timer with box and controls hint
draw_timer_boxed :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	width: int,
	remaining: time.Duration,
	total: time.Duration,
	state: Timer_State,
	title: string = "Timer",
) {
	height := 8

	// Draw box
	draw_box_titled(buf, pos, width, height, title, .Single, .BrightCyan, .BrightWhite)

	// Draw timer
	time_x := pos.x + width / 2 - 8
	time_y := pos.y + 2
	draw_timer_with_progress(buf, {time_x, time_y}, remaining, total, state, width - 4)

	// Draw controls
	controls := "[Space] Start/Pause  [r] Reset"
	munin.print_at(buf, {pos.x + 2, pos.y + height - 2}, controls, .BrightBlue)
}

// Draw preset timer buttons
draw_timer_presets :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	presets: []int, // Duration in seconds
	selected: int = -1,
) {
	munin.print_at(buf, pos, "Quick Timers:", .BrightCyan)

	for duration, i in presets {
		button_x := pos.x + (i * 12)
		button_y := pos.y + 2

		is_selected := i == selected

		// Draw button background
		if is_selected {
			munin.set_bg_color(buf, .BrightBlue)
		}

		// Format button text
		minutes := duration / 60
		seconds := duration % 60
		button_text := ""
		if minutes > 0 {
			button_text = fmt.tprintf(" %dm ", minutes)
		} else {
			button_text = fmt.tprintf(" %ds ", seconds)
		}

		color := is_selected ? munin.Color.White : munin.Color.BrightGreen
		munin.print_at(buf, {button_x, button_y}, button_text, color)
		munin.reset_style(buf)
	}
}
