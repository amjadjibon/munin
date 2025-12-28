package main

import comp "../../munin/components"
import munin "../../munin"
import "core:fmt"
import "core:mem"
import "core:strings"

// Model holds the application state
Model :: struct {
	progress1:      int, // Simple progress (0-100)
	progress2:      int, // Download simulation (0-100)
	progress3:      int, // Upload simulation (0-100)
	progress4:      int, // Processing simulation (0-100)
	selected_style: int,
	paused:         bool,
	message:        string,
}

init :: proc() -> Model {
	return Model {
		progress1 = 0,
		progress2 = 25,
		progress3 = 60,
		progress4 = 80,
		selected_style = 0,
		paused = false,
		message = "Progress bars animating. Press SPACE to pause, arrows to change style.",
	}
}

// Messages define all possible events
Tick :: struct {}
TogglePause :: struct {}
NextStyle :: struct {}
PrevStyle :: struct {}
Reset :: struct {}
Quit :: struct {}

Msg :: union {
	Tick,
	TogglePause,
	NextStyle,
	PrevStyle,
	Reset,
	Quit,
}

// Update handles state transitions
update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case Tick:
		if !model.paused {
			// Animate different progress bars at different speeds
			new_model.progress1 = (model.progress1 + 1) % 101
			new_model.progress2 = (model.progress2 + 2) % 101
			new_model.progress3 = (model.progress3 + 3) % 101
			new_model.progress4 = (model.progress4 + 1) % 101
		}
	case TogglePause:
		new_model.paused = !model.paused
		if new_model.paused {
			new_model.message = "Animation PAUSED. Press SPACE to resume."
		} else {
			new_model.message = "Animation RESUMED. Press SPACE to pause."
		}
	case NextStyle:
		new_model.selected_style = (model.selected_style + 1) % 5
		new_model.message = fmt.tprintf(
			"Style: %s",
			get_style_name(comp.Progress_Style(new_model.selected_style)),
		)
	case PrevStyle:
		new_model.selected_style = (model.selected_style - 1 + 5) % 5
		new_model.message = fmt.tprintf(
			"Style: %s",
			get_style_name(comp.Progress_Style(new_model.selected_style)),
		)
	case Reset:
		new_model.progress1 = 0
		new_model.progress2 = 25
		new_model.progress3 = 60
		new_model.progress4 = 80
		new_model.message = "Progress bars reset to initial values."
	case Quit:
		should_quit = true
	}

	return new_model, should_quit
}

get_style_name :: proc(style: comp.Progress_Style) -> string {
	switch style {
	case .Blocks:
		return "Blocks"
	case .Bars:
		return "Bars"
	case .Dots:
		return "Dots"
	case .Arrow:
		return "Arrow"
	case .Gradient:
		return "Gradient"
	}
	return "Unknown"
}

get_style_description :: proc(style: comp.Progress_Style) -> string {
	switch style {
	case .Blocks:
		return "Solid block characters (████░░░░)"
	case .Bars:
		return "Vertical bar characters (||||)"
	case .Dots:
		return "Filled and empty dots (●●●○○○)"
	case .Arrow:
		return "Arrow pointing right (====>---)"
	case .Gradient:
		return "Gradient shading (▓▓▒▒░░░)"
	}
	return ""
}

// View renders the current state
view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)

	// Get terminal size
	term_width, term_height, ok := munin.get_window_size()
	if !ok {
		term_width = 80
		term_height = 24
	}

	// Set window title
	munin.set_window_title(buf, "Munin Progress Bar Demo")

	// Header
	title := "Progress Bar Component Showcase"
	munin.draw_title(buf, {0, 1}, term_width, title, .BrightCyan, bold = true)

	// Current style info
	style_name := get_style_name(comp.Progress_Style(model.selected_style))
	style_desc := get_style_description(comp.Progress_Style(model.selected_style))
	munin.print_at(buf, {2, 3}, fmt.tprintf("Current Style: %s", style_name), .BrightYellow)
	munin.print_at(buf, {2, 4}, style_desc, .BrightBlack)

	// Status
	status := "Animating"
	if model.paused {
		status = "Paused"
	}
	munin.print_at(buf, {2, 5}, fmt.tprintf("Status: %s", status), .BrightGreen)

	start_y := 7
	bar_width := 40

	current_style := comp.Progress_Style(model.selected_style)

	// Section 1: All styles showcase
	munin.print_at(buf, {2, start_y}, "All Progress Bar Styles:", .BrightWhite)

	styles := []comp.Progress_Style{.Blocks, .Bars, .Dots, .Arrow, .Gradient}
	style_names := []string{"Blocks", "Bars", "Dots", "Arrow", "Gradient"}
	colors := []munin.Color{.BrightGreen, .BrightCyan, .BrightYellow, .BrightMagenta, .BrightBlue}

	// Show all 5 styles with 50% progress
	for i in 0 ..< len(styles) {
		y := start_y + 2 + i * 2
		label_color := munin.Basic_Color.White
		if i == model.selected_style {
			label_color = .BrightYellow
			munin.print_at(buf, {2, y}, ">", .BrightYellow)
		}

		munin.print_at(buf, {4, y}, style_names[i], label_color)
		comp.draw_progress_bar(
			buf,
			{15, y},
			bar_width,
			50,
			styles[i],
			colors[i],
			.BrightBlack,
			true,
		)
	}

	// Section 2: Different progress values
	demo_y := start_y + 14
	munin.print_at(buf, {2, demo_y}, "Progress Values Demo:", .BrightWhite)

	progress_values := []int{0, 25, 50, 75, 100}
	progress_labels := []string{"0%", "25%", "50%", "75%", "100%"}

	for i in 0 ..< len(progress_values) {
		y := demo_y + 2 + i
		munin.print_at(buf, {4, y}, progress_labels[i], .White)
		comp.draw_progress_bar(
			buf,
			{15, y},
			bar_width,
			progress_values[i],
			current_style,
			.BrightGreen,
			.BrightBlack,
			false,
		)
	}

	// Section 3: Animated progress bars
	animated_y := demo_y + 9
	munin.print_at(buf, {2, animated_y}, "Animated Progress Bars:", .BrightWhite)

	// Progress 1: Simple animation
	munin.print_at(buf, {4, animated_y + 2}, "Simple:", .White)
	comp.draw_progress_bar(
		buf,
		{15, animated_y + 2},
		bar_width,
		model.progress1,
		current_style,
		.BrightCyan,
		.BrightBlack,
		true,
	)

	// Progress 2: Download simulation
	munin.print_at(buf, {4, animated_y + 3}, "Download:", .White)
	comp.draw_progress_bar(
		buf,
		{15, animated_y + 3},
		bar_width,
		model.progress2,
		current_style,
		.BrightGreen,
		.BrightBlack,
		true,
	)

	// Progress 3: Upload simulation
	munin.print_at(buf, {4, animated_y + 4}, "Upload:", .White)
	comp.draw_progress_bar(
		buf,
		{15, animated_y + 4},
		bar_width,
		model.progress3,
		current_style,
		.BrightYellow,
		.BrightBlack,
		true,
	)

	// Progress 4: Processing simulation
	munin.print_at(buf, {4, animated_y + 5}, "Process:", .White)
	comp.draw_progress_bar(
		buf,
		{15, animated_y + 5},
		bar_width,
		model.progress4,
		current_style,
		.BrightMagenta,
		.BrightBlack,
		true,
	)

	// Section 4: Boxed progress bars
	boxed_y := animated_y + 8
	// Only show boxed progress bars if we have enough space
	if boxed_y + 6 < term_height - 8 {
		munin.print_at(buf, {2, boxed_y}, "Boxed Progress Bars:", .BrightWhite)

		comp.draw_progress_bar_boxed(
			buf,
			4,
			boxed_y + 2,
			bar_width + 2,
			model.progress1,
			"Installing packages...",
			.BrightGreen,
			.BrightBlack,
		)
	}

	// Section 5: Vertical progress bars
	vertical_x := 70
	munin.print_at(buf, {vertical_x, start_y}, "Vertical:", .BrightWhite)

	comp.draw_progress_bar_vertical(
		buf,
		vertical_x,
		start_y + 2,
		15,
		model.progress1,
		.BrightCyan,
		.BrightBlack,
	)
	comp.draw_progress_bar_vertical(
		buf,
		vertical_x + 3,
		start_y + 2,
		15,
		model.progress2,
		.BrightGreen,
		.BrightBlack,
	)
	comp.draw_progress_bar_vertical(
		buf,
		vertical_x + 6,
		start_y + 2,
		15,
		model.progress3,
		.BrightYellow,
		.BrightBlack,
	)
	comp.draw_progress_bar_vertical(
		buf,
		vertical_x + 9,
		start_y + 2,
		15,
		model.progress4,
		.BrightMagenta,
		.BrightBlack,
	)

	// Instructions at bottom
	instructions_y := term_height - 6
	munin.print_at(buf, {2, instructions_y}, model.message, .BrightYellow)
	munin.print_at(buf, {2, instructions_y + 1}, "Controls:", .BrightWhite)
	munin.print_at(buf, {2, instructions_y + 2}, "  ← → : Change progress bar style", .White)
	munin.print_at(buf, {2, instructions_y + 3}, "  SPACE : Pause/Resume animation", .White)
	munin.print_at(buf, {2, instructions_y + 4}, "  R : Reset progress  |  Q : Quit", .White)
}

// Subscription for animation ticks
subscriptions :: proc(model: Model) -> Maybe(Msg) {
	return Tick{}
}

// Input handler processes keyboard events
input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_key().?; ok {
		#partial switch event.key {
		case .Right:
			return NextStyle{}
		case .Left:
			return PrevStyle{}
		case .Char:
			switch event.char {
			case ' ':
				return TogglePause{}
			case 'r', 'R':
				return Reset{}
			case 'q', 'Q', 3:
				// q, Q, or Ctrl+C
				return Quit{}
			}
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

	// Create and run program with subscriptions for animation
	program := munin.make_program(init, update, view, subscriptions)
	munin.run(&program, input_handler, target_fps = 10) // 10 FPS for smooth progress animation
}
