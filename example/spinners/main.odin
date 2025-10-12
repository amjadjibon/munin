package main

import comp "../../components"
import munin "../../munin"
import "core:fmt"
import "core:mem"
import "core:strings"

// Model holds the application state
Model :: struct {
	frame:          int,
	selected_style: int,
	paused:         bool,
	direction:      comp.Spinner_Direction,
	message:        string,
}

init :: proc() -> Model {
	return Model{
		frame = 0,
		selected_style = 0,
		paused = false,
		direction = .Forward,
		message = "Spinners animating. Press SPACE to pause, arrows to change style, R to reverse.",
	}
}

// Messages define all possible events
Tick :: struct {}
TogglePause :: struct {}
ToggleDirection :: struct {}
NextStyle :: struct {}
PrevStyle :: struct {}
Quit :: struct {}

Msg :: union {
	Tick,
	TogglePause,
	ToggleDirection,
	NextStyle,
	PrevStyle,
	Quit,
}

// Update handles state transitions
update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case Tick:
		if !model.paused {
			new_model.frame += 1
		}
	case TogglePause:
		new_model.paused = !model.paused
		if new_model.paused {
			new_model.message = "Animation PAUSED. Press SPACE to resume."
		} else {
			new_model.message = "Animation RESUMED. Press SPACE to pause."
		}
	case ToggleDirection:
		if new_model.direction == .Forward {
			new_model.direction = .Reverse
			new_model.message = "Direction: REVERSE (counter-clockwise)"
		} else {
			new_model.direction = .Forward
			new_model.message = "Direction: FORWARD (clockwise)"
		}
	case NextStyle:
		new_model.selected_style = (model.selected_style + 1) % 8
		new_model.message = fmt.tprintf(
			"Style: %s - %s",
			get_style_name(comp.Spinner_Style(new_model.selected_style)),
			get_style_description(comp.Spinner_Style(new_model.selected_style)),
		)
	case PrevStyle:
		new_model.selected_style = (model.selected_style - 1 + 8) % 8
		new_model.message = fmt.tprintf(
			"Style: %s - %s",
			get_style_name(comp.Spinner_Style(new_model.selected_style)),
			get_style_description(comp.Spinner_Style(new_model.selected_style)),
		)
	case Quit:
		should_quit = true
	}

	return new_model, should_quit
}

get_style_name :: proc(style: comp.Spinner_Style) -> string {
	switch style {
	case .Dots:
		return "Dots"
	case .Line:
		return "Line"
	case .Arrow:
		return "Arrow"
	case .Circle:
		return "Circle"
	case .Box:
		return "Box"
	case .Star:
		return "Star"
	case .Moon:
		return "Moon"
	case .Clock:
		return "Clock"
	}
	return "Unknown"
}

get_style_description :: proc(style: comp.Spinner_Style) -> string {
	switch style {
	case .Dots:
		return "Braille dot pattern animation"
	case .Line:
		return "Classic rotating line spinner"
	case .Arrow:
		return "Rotating arrow directions"
	case .Circle:
		return "Half-circle rotation"
	case .Box:
		return "Box corner animation"
	case .Star:
		return "Pulsing star effect"
	case .Moon:
		return "Moon phase animation"
	case .Clock:
		return "Clock face rotation"
	}
	return ""
}

// View renders the current state
view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)

	// Get terminal size for responsive layout
	term_width, term_height, ok := munin.get_window_size()
	if !ok {
		term_width = 80
		term_height = 24
	}

	// Set window title
	munin.set_window_title(buf, "Munin Spinner Components Demo")

	// Header
	title := "Spinner Component Showcase"
	munin.draw_title(buf, {0, 1}, term_width, title, .BrightCyan, bold = true)

	// Current style info
	style_name := get_style_name(comp.Spinner_Style(model.selected_style))
	munin.print_at(buf, {2, 3}, fmt.tprintf("Current Style: %s", style_name), .BrightYellow)

	// Status
	status := "Running"
	if model.paused {
		status = "Paused"
	}
	munin.print_at(buf, {2, 4}, fmt.tprintf("Status: %s", status), .BrightGreen)

	// Direction
	direction_str := "Forward (Clockwise)"
	if model.direction == .Reverse {
		direction_str = "Reverse (Counter-clockwise)"
	}
	munin.print_at(buf, {2, 5}, fmt.tprintf("Direction: %s", direction_str), .BrightMagenta)

	start_y := 7

	// Section 1: All spinner styles showcase
	munin.print_at(buf, {2, start_y}, "All Spinner Styles:", .BrightWhite)

	styles := []comp.Spinner_Style{.Dots, .Line, .Arrow, .Circle, .Box, .Star, .Moon, .Clock}
	style_names := []string{"Dots", "Line", "Arrow", "Circle", "Box", "Star", "Moon", "Clock"}
	colors := []munin.Color {
		.BrightCyan,
		.BrightGreen,
		.BrightYellow,
		.BrightMagenta,
		.BrightBlue,
		.BrightRed,
		.Cyan,
		.Yellow,
	}

	// Display all spinners in a grid
	for i in 0 ..< len(styles) {
		row := i / 4
		col := i % 4
		x := 4 + col * 30
		y := start_y + 2 + row * 3

		// Highlight selected style
		label_color := munin.Color.White
		if i == model.selected_style {
			label_color = .BrightYellow
			munin.print_at(buf, {x - 2, y}, ">", .BrightYellow)
		}

		comp.draw_spinner(buf, {x, y}, model.frame, styles[i], colors[i], "", model.direction)
		munin.print_at(buf, {x + 3, y}, style_names[i], label_color)
	}

	// Section 2: Large demonstration of selected style
	demo_y := start_y + 10
	munin.print_at(buf, {2, demo_y}, "Selected Style Demo:", .BrightWhite)

	// Large spinner with box
	demo_box_x := 4
	demo_box_y := demo_y + 2
	comp.draw_box_styled(buf, {demo_box_x, demo_box_y}, 60, 8, .Rounded, .BrightBlue)

	selected_style := comp.Spinner_Style(model.selected_style)
	spinner_x := demo_box_x + 28
	spinner_y := demo_box_y + 3

	comp.draw_spinner(
		buf,
		{spinner_x, spinner_y},
		model.frame,
		selected_style,
		.BrightCyan,
		"",
		model.direction,
	)

	// Description
	desc := get_style_description(selected_style)
	munin.print_at(buf, {demo_box_x + 2, spinner_y + 1}, desc, .BrightBlack)

	// Section 3: Use case examples
	examples_y := demo_y + 12
	// Only show use cases if we have enough space
	if examples_y + 4 < term_height - 8 {
		munin.print_at(buf, {2, examples_y}, "Common Use Cases:", .BrightWhite)

		// Loading example
		comp.draw_spinner(
			buf,
			{4, examples_y + 2},
			model.frame,
			.Dots,
			.BrightGreen,
			"Loading...",
			model.direction,
		)

		// Processing example
		comp.draw_spinner(
			buf,
			{4, examples_y + 3},
			model.frame,
			.Circle,
			.BrightYellow,
			"Processing data...",
			model.direction,
		)
	}

	// Instructions at bottom
	instructions_y := term_height - 6
	munin.print_at(buf, {2, instructions_y}, model.message, .BrightYellow)
	munin.print_at(buf, {2, instructions_y + 1}, "Controls:", .BrightWhite)
	munin.print_at(buf, {2, instructions_y + 2}, "  ← → : Change spinner style", .White)
	munin.print_at(buf, {2, instructions_y + 3}, "  SPACE : Pause/Resume animation", .White)
	munin.print_at(buf, {2, instructions_y + 4}, "  R : Toggle rotation direction  |  Q : Quit", .White)
}

// Subscription for animation ticks
subscriptions :: proc(model: Model) -> Maybe(Msg) {
	// Always tick to keep animation running
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
				return ToggleDirection{}
			case 'q', 'Q', 3: // q, Q, or Ctrl+C
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
	munin.run(&program, input_handler, target_fps = 15) // 15 FPS for smooth spinner animation
}
