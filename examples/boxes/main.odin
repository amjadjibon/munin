package main

import comp "../../munin/components"
import munin "../../munin"
import "core:fmt"
import "core:mem"
import "core:strings"

// Model holds the application state
Model :: struct {
	selected_style: int,
	message:        string,
}

init :: proc() -> Model {
	return Model{selected_style = 0, message = "Use arrow keys to navigate, q to quit"}
}

// Messages define all possible events
NextStyle :: struct {}
PrevStyle :: struct {}
Quit :: struct {}

Msg :: union {
	NextStyle,
	PrevStyle,
	Quit,
}

// Update handles state transitions
update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case NextStyle:
		new_model.selected_style = (model.selected_style + 1) % 5
		new_model.message = get_style_description(comp.Box_Style(new_model.selected_style))
	case PrevStyle:
		new_model.selected_style = (model.selected_style - 1 + 5) % 5
		new_model.message = get_style_description(comp.Box_Style(new_model.selected_style))
	case Quit:
		should_quit = true
	}

	return new_model, should_quit
}

get_style_description :: proc(style: comp.Box_Style) -> string {
	switch style {
	case .Single:
		return "Single line border - Clean and minimal"
	case .Double:
		return "Double line border - Bold and prominent"
	case .Rounded:
		return "Rounded corners - Modern and smooth"
	case .Bold:
		return "Bold lines - Strong emphasis"
	case .Ascii:
		return "ASCII characters - Universal compatibility"
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
	munin.set_window_title(buf, "Munin Box Components Demo")

	// Header
	title := "Box Component Showcase"
	munin.draw_title(buf, {0, 1}, term_width, title, .BrightCyan, bold = true)

	// Current style name
	style_name := get_style_name(comp.Box_Style(model.selected_style))
	munin.print_at(buf, {2, 3}, fmt.tprintf("Current Style: %s", style_name), .BrightYellow)

	// Calculate layout
	box_width := 50
	box_height := 10
	start_y := 5

	current_style := comp.Box_Style(model.selected_style)

	// Demo 1: Simple styled box
	demo1_x := 2
	comp.draw_box_styled(
		buf,
		{demo1_x, start_y},
		box_width,
		box_height,
		current_style,
		.BrightGreen,
	)
	munin.print_at(buf, {demo1_x + 2, start_y + 4}, "Simple Styled Box", .White)
	munin.print_at(buf, {demo1_x + 2, start_y + 5}, "No title, just borders", .BrightBlack)

	// Demo 2: Box with title
	demo2_x := demo1_x + box_width + 4
	if demo2_x + box_width < term_width - 2 {
		comp.draw_box_titled(
			buf,
			{demo2_x, start_y},
			box_width,
			box_height,
			"Titled Box",
			current_style,
			.BrightBlue,
			.BrightWhite,
		)
		munin.print_at(buf, {demo2_x + 2, start_y + 4}, "Box with Title", .White)
		munin.print_at(buf, {demo2_x + 2, start_y + 5}, "Title in top border", .BrightBlack)
	}

	// Demo 3: Filled box
	demo3_y := start_y + box_height + 2
	comp.draw_box_filled(
		buf,
		{demo1_x, demo3_y},
		box_width,
		box_height,
		.Blue,
		current_style,
		.BrightYellow,
	)
	munin.print_at(buf, {demo1_x + 2, demo3_y + 4}, "Filled Box", .BrightWhite)
	munin.print_at(buf, {demo1_x + 2, demo3_y + 5}, "Background color + border", .BrightWhite)

	// Demo 4: Multiple colors showcase
	if demo2_x + box_width < term_width - 2 {
		colors := []munin.Color{.Red, .Green, .Yellow, .Magenta, .Cyan}
		color_names := []string{"Red", "Green", "Yellow", "Magenta", "Cyan"}

		small_box_height := 5
		for i in 0 ..< len(colors) {
			y := demo3_y + i * (small_box_height + 1)
			if y + small_box_height < term_height - 3 {
				comp.draw_box_styled(
					buf,
					{demo2_x, y},
					box_width,
					small_box_height,
					current_style,
					colors[i],
				)
				munin.print_at(buf, {demo2_x + 2, y + 2}, color_names[i], colors[i])
			}
		}
	}

	// Instructions at bottom
	instructions_y := term_height - 4
	munin.print_at(buf, {2, instructions_y}, model.message, .BrightYellow)
	munin.print_at(buf, {2, instructions_y + 1}, "Controls:", .BrightWhite)
	munin.print_at(
		buf,
		{2, instructions_y + 2},
		"  ← → : Change box style  |  Q : Quit",
		.White,
	)
}

get_style_name :: proc(style: comp.Box_Style) -> string {
	switch style {
	case .Single:
		return "Single"
	case .Double:
		return "Double"
	case .Rounded:
		return "Rounded"
	case .Bold:
		return "Bold"
	case .Ascii:
		return "ASCII"
	}
	return "Unknown"
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

	// Create and run program
	program := munin.make_program(init, update, view)
	munin.run(&program, input_handler, target_fps = 60)
}
