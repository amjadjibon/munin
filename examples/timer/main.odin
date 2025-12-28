package main

import comp "../../munin/components"
import munin "../../munin"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:time"

// Global variables for timer timing
last_timer_update: time.Time
timer_initialized: bool

// Model holds the application state
Model :: struct {
	remaining_time:    time.Duration,
	total_time:        time.Duration,
	timer_state:       comp.Timer_State,
	show_milliseconds: bool,
	selected_preset:   int,
	current_demo:      int,
	last_tick:         time.Time,
}

init :: proc() -> Model {
	return Model {
		remaining_time    = 60 * time.Second,
		total_time        = 60 * time.Second,
		timer_state       = .Ready,
		show_milliseconds = false,
		selected_preset   = 2, // 1 minute
		current_demo      = 0,
		last_tick         = time.now(),
	}
}

// Messages define all possible events
Quit :: struct {}
StartPause :: struct {}
Reset :: struct {}
ToggleMilliseconds :: struct {}
NextPreset :: struct {}
PrevPreset :: struct {}
SelectPreset :: struct {}
NextDemo :: struct {}
PrevDemo :: struct {}
Tick :: struct {} // Timer tick message

Msg :: union {
	Quit,
	StartPause,
	Reset,
	ToggleMilliseconds,
	NextPreset,
	PrevPreset,
	SelectPreset,
	NextDemo,
	PrevDemo,
	Tick,
}

// Get preset timer durations in seconds
get_timer_presets :: proc() -> [10]int {
	return [10]int {
		5, // 5 seconds
		10, // 10 seconds
		30, // 30 seconds
		60, // 1 minute
		120, // 2 minutes
		300, // 5 minutes
		600, // 10 minutes
		900, // 15 minutes
		1800, // 30 minutes
		3600, // 1 hour
	}
}

// Update handles state transitions
update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case Quit:
		should_quit = true
	case StartPause:
		switch model.timer_state {
		case .Ready, .Paused:
			new_model.timer_state = .Running
			new_model.last_tick = time.now()
		case .Running:
			new_model.timer_state = .Paused
		case .Finished:
			// Restart timer
			new_model.remaining_time = model.total_time
			new_model.timer_state = .Running
			new_model.last_tick = time.now()
		}
	case Reset:
		new_model.remaining_time = model.total_time
		new_model.timer_state = .Ready
	case ToggleMilliseconds:
		new_model.show_milliseconds = !model.show_milliseconds
	case NextPreset:
		presets := get_timer_presets()
		new_model.selected_preset = (model.selected_preset + 1) % len(presets)
		new_model.total_time = time.Duration(presets[new_model.selected_preset]) * time.Second
		new_model.remaining_time = new_model.total_time
		new_model.timer_state = .Ready
	case PrevPreset:
		presets := get_timer_presets()
		new_model.selected_preset = (model.selected_preset - 1 + len(presets)) % len(presets)
		new_model.total_time = time.Duration(presets[new_model.selected_preset]) * time.Second
		new_model.remaining_time = new_model.total_time
		new_model.timer_state = .Ready
	case SelectPreset:
		presets := get_timer_presets()
		new_model.total_time = time.Duration(presets[model.selected_preset]) * time.Second
		new_model.remaining_time = new_model.total_time
		new_model.timer_state = .Ready
	case NextDemo:
		new_model.current_demo = (model.current_demo + 1) % 4
	case PrevDemo:
		new_model.current_demo = (model.current_demo - 1 + 4) % 4
	case Tick:
		if model.timer_state == .Running {
			now := time.now()
			delta := time.diff(model.last_tick, now)
			new_model.last_tick = now

			if model.remaining_time > delta {
				new_model.remaining_time -= delta
			} else {
				new_model.remaining_time = 0
				new_model.timer_state = .Finished
			}
		}
	}

	return new_model, should_quit
}

// View renders the current state
view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)

	// Set window title
	munin.set_window_title(buf, "Munin Timer Component Examples")

	// Header
	title := "Timer Component Examples"
	munin.draw_title(buf, {0, 1}, 80, title, .BrightCyan)

	// Demo navigation
	munin.print_at(buf, {2, 3}, "Demos:", .BrightWhite)
	demos := []string{"Basic Timer", "Timer with Progress", "Boxed Timer", "Interactive Timer"}

	for i in 0 ..< len(demos) {
		color := munin.Basic_Color.White
		if i == model.current_demo {
			color = .BrightYellow
		}
		item_display := fmt.tprintf("[%d] %s", i + 1, demos[i])
		munin.print_at(buf, {12 + i * 16, 3}, item_display, color)
	}

	// Current demo description
	descriptions := []string {
		"Simple countdown timer with state indicators",
		"Timer with circular progress bar visualization",
		"Timer in styled box with controls hint",
		"Full interactive timer with presets and controls",
	}

	desc_x := max(2, (80 - len(descriptions[model.current_demo])) / 2)
	munin.print_at(buf, {desc_x, 5}, descriptions[model.current_demo], .BrightGreen)

	// Draw current demo
	draw_demo(buf, model)

	// Help section
	draw_help(buf)
}

// Draw help section
draw_help :: proc(buf: ^strings.Builder) {
	help_y := 22
	munin.print_at(buf, {2, help_y}, "Controls:", .BrightWhite)
	munin.print_at(buf, {2, help_y + 1}, "  ← → : Switch demos | 1-4 : Jump to demo", .White)
	munin.print_at(
		buf,
		{2, help_y + 2},
		"  Space : Start/Pause | R : Reset | M : Toggle milliseconds",
		.White,
	)
	munin.print_at(buf, {2, help_y + 3}, "  Q : Quit", .White)
}

// Draw the current demo
draw_demo :: proc(buf: ^strings.Builder, model: Model) {
	demo_y := 8
	demo_x := 10

	switch model.current_demo {
	case 0:
		draw_basic_timer_demo(buf, {demo_x, demo_y}, model)
	case 1:
		draw_progress_timer_demo(buf, {demo_x, demo_y}, model)
	case 2:
		draw_boxed_timer_demo(buf, {demo_x, demo_y}, model)
	case 3:
		draw_interactive_timer_demo(buf, {demo_x, demo_y}, model)
	}
}

// Basic timer demo
draw_basic_timer_demo :: proc(buf: ^strings.Builder, pos: munin.Vec2i, model: Model) {
	comp.draw_box_styled(buf, {pos.x - 2, pos.y - 1}, 60, 8, .Rounded, .BrightBlue)
	munin.print_at(buf, {pos.x + 18, pos.y - 1}, "BASIC TIMER", .BrightWhite)

	// Draw timer at center of box
	// Box starts at pos.x - 2, width 60, so center is at pos.x - 2 + 30 = pos.x + 28
	// Timer text is about 12 characters long, so center it: pos.x + 28 - 6 = pos.x + 22
	timer_x := pos.x + 22
	comp.draw_timer(
		buf,
		{timer_x, pos.y + 3},
		model.remaining_time,
		model.timer_state,
		model.show_milliseconds,
	)

	// Show milliseconds setting
	ms_text := model.show_milliseconds ? "ON" : "OFF"
	ms_color: munin.Color
	if model.show_milliseconds {
		ms_color = .BrightGreen
	} else {
		ms_color = .BrightRed
	}
	munin.print_at(buf, {pos.x + 10, pos.y + 5}, "Milliseconds:", .White)
	munin.print_at(buf, {pos.x + 23, pos.y + 5}, ms_text, ms_color)
}

// Timer with progress demo
draw_progress_timer_demo :: proc(buf: ^strings.Builder, pos: munin.Vec2i, model: Model) {
	comp.draw_box_styled(buf, {pos.x - 2, pos.y - 1}, 60, 10, .Rounded, .BrightGreen)
	munin.print_at(buf, {pos.x + 13, pos.y - 1}, "TIMER WITH PROGRESS", .BrightWhite)

	// Draw timer with progress - center the timer with progress bar
	// Box center is at pos.x + 28, progress bar width 40, so center it at pos.x + 28 - 20 = pos.x + 8
	timer_x := pos.x + 8
	comp.draw_timer_with_progress(
		buf,
		{timer_x, pos.y + 2},
		model.remaining_time,
		model.total_time,
		model.timer_state,
		40,
	)

	// Show percentage
	percentage := 0
	if model.total_time > 0 {
		elapsed := model.total_time - model.remaining_time
		percentage = int(
			(time.duration_seconds(elapsed) / time.duration_seconds(model.total_time)) * 100,
		)
		percentage = clamp(percentage, 0, 100)
	}

	perc_text := fmt.tprintf("Progress: %d%%", percentage)
	munin.print_at(buf, {pos.x + 18, pos.y + 6}, perc_text, .BrightYellow)
}

// Boxed timer demo
draw_boxed_timer_demo :: proc(buf: ^strings.Builder, pos: munin.Vec2i, model: Model) {
	comp.draw_timer_boxed(
		buf,
		pos,
		56,
		model.remaining_time,
		model.total_time,
		model.timer_state,
		"Demo Timer",
	)
}

// Interactive timer demo
draw_interactive_timer_demo :: proc(buf: ^strings.Builder, pos: munin.Vec2i, model: Model) {
	comp.draw_box_styled(buf, {pos.x - 2, pos.y - 1}, 60, 15, .Rounded, .BrightMagenta)
	munin.print_at(buf, {pos.x + 13, pos.y - 1}, "INTERACTIVE TIMER", .BrightWhite)

	// Draw timer - center the timer with progress bar
	// Box center is at pos.x + 28, progress bar width 36, so center it at pos.x + 28 - 18 = pos.x + 10
	timer_x := pos.x + 10
	comp.draw_timer_with_progress(
		buf,
		{timer_x, pos.y + 1},
		model.remaining_time,
		model.total_time,
		model.timer_state,
		36,
	)

	// Draw preset buttons
	presets := get_timer_presets()
	preset_x := pos.x + 5
	preset_y := pos.y + 5
	comp.draw_timer_presets(buf, {preset_x, preset_y}, presets[:], model.selected_preset)

	// Show current selection info
	selected_seconds := presets[model.selected_preset]
	minutes := selected_seconds / 60
	seconds := selected_seconds % 60

	selected_text := ""
	if minutes > 0 {
		selected_text = fmt.tprintf("Selected: %dm %ds", minutes, seconds)
	} else {
		selected_text = fmt.tprintf("Selected: %ds", seconds)
	}

	munin.print_at(buf, {pos.x + 5, pos.y + 9}, selected_text, .BrightCyan)

	// Show controls hint
	controls := "← → : Select preset  Space : Start/Pause  R : Reset"
	munin.print_at(buf, {pos.x + 5, pos.y + 11}, controls, .BrightBlue)
}

// Input handler processes keyboard events
input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_key().?; ok {
		#partial switch event.key {
		case .Enter:
			return StartPause{}
		case .Left:
			return PrevPreset{}
		case .Right:
			return NextPreset{}
		case .Char:
			if event.char == 'q' || event.char == 'Q' || event.char == 3 {
				return Quit{}
			} else if event.char == ' ' {
				return StartPause{}
			} else if event.char == 'r' || event.char == 'R' {
				return Reset{}
			} else if event.char == 'm' || event.char == 'M' {
				return ToggleMilliseconds{}
			} else if event.char >= '1' && event.char <= '4' {
				demo_index := int(event.char - '1')
				// Set demo by updating current_demo directly
				return NextDemo{} // We'll handle this properly in main
			}
		}
	}
	return nil
}

// Subscription for timer ticks
subscription :: proc(model: Model) -> Maybe(Msg) {
	// Check if enough time has passed for timer update
	if !timer_initialized {
		last_timer_update = time.now()
		timer_initialized = true
	}

	current_time := time.now()
	elapsed_ms := time.diff(last_timer_update, current_time) / time.Millisecond

	if elapsed_ms >= 50 { 	// Update every 50ms for smooth countdown
		last_timer_update = current_time
		if model.timer_state == .Running {
			return Tick{}
		}
	}

	return nil
}

main :: proc() {
	// Debug-time memory tracking
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	// Create and run program with subscriptions
	program := munin.make_program_with_subs(init, update, view, subscription)
	munin.run(&program, input_handler, target_fps = 60)
}
