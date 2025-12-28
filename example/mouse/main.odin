package main

import munin "../../munin"
import "core:fmt"
import "core:strings"

// 1. Define your Model
Model :: struct {
	screen_width:  int,
	screen_height: int,
	last_mouse_x:  int,
	last_mouse_y:  int,
	last_button:   munin.Mouse_Button,
	last_event:    munin.Mouse_Event_Type,
	click_count:   int,
	scroll_count:  int,
	scroll_up:     int,
	scroll_down:   int,
	drag_path:     [dynamic]munin.Vec2i,
}

init :: proc() -> Model {
	return Model {
		screen_width = 80,
		screen_height = 24,
		last_mouse_x = -1,
		last_mouse_y = -1,
		last_button = .None,
		last_event = .Move,
		click_count = 0,
		scroll_count = 0,
		scroll_up = 0,
		scroll_down = 0,
		drag_path = make([dynamic]munin.Vec2i),
	}
}

// 2. Define your Messages
Mouse_Input :: struct {
	event: munin.Mouse_Event,
}

Key_Input :: struct {
	event: munin.Key_Event,
}

Quit :: struct {}

Msg :: union {
	Mouse_Input,
	Key_Input,
	Quit,
}

// 3. Define your Update function
update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case Mouse_Input:
		new_model.last_mouse_x = m.event.x
		new_model.last_mouse_y = m.event.y
		new_model.last_button = m.event.button
		new_model.last_event = m.event.type

		if m.event.type == .Press {
			// Count scroll events separately
			if m.event.button == .WheelUp {
				new_model.scroll_count += 1
				new_model.scroll_up += 1
			} else if m.event.button == .WheelDown {
				new_model.scroll_count += 1
				new_model.scroll_down += 1
			} else {
				new_model.click_count += 1
			}
		}

		// Track drag path
		if m.event.type == .Drag {
			append(&new_model.drag_path, munin.Vec2i{m.event.x, m.event.y})
		} else if m.event.type == .Release {
			clear(&new_model.drag_path)
		}

	case Key_Input:
		if m.event.key == .Char {
			switch m.event.char {
			case 'q', 'Q', 3:
				// q, Q, or Ctrl+C
				should_quit = true
			case 'c', 'C':
				// Clear all counts
				new_model.click_count = 0
				new_model.scroll_count = 0
				new_model.scroll_up = 0
				new_model.scroll_down = 0
			}
		}

	case Quit:
		should_quit = true
	}

	return new_model, should_quit
}

// 4. Define your View function
view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)

	// Title
	title := "MOUSE TRACKING DEMO"
	munin.set_bold(buf)
	munin.print_at(buf, {(model.screen_width - len(title)) / 2, 1}, title, .BrightCyan)
	munin.reset_style(buf)

	// Draw border
	munin.draw_box(buf, {0, 0}, model.screen_width, model.screen_height, .White)

	// Mouse info section
	y := 3
	munin.print_at(buf, {2, y}, "Mouse Position:", .BrightYellow)
	if model.last_mouse_x >= 0 {
		munin.print_at(
			buf,
			{18, y},
			fmt.tprintf("X: %3d, Y: %3d", model.last_mouse_x, model.last_mouse_y),
			.White,
		)
	} else {
		munin.print_at(buf, {18, y}, "Move mouse to see position", .BrightBlack)
	}
	y += 2

	munin.print_at(buf, {2, y}, "Last Button:", .BrightYellow)
	button_str := ""
	button_color := munin.Basic_Color.White
	switch model.last_button {
	case .None:
		button_str = "None"
		button_color = .BrightBlack
	case .Left:
		button_str = "Left"
		button_color = .BrightGreen
	case .Right:
		button_str = "Right"
		button_color = .BrightRed
	case .Middle:
		button_str = "Middle"
		button_color = .BrightYellow
	case .WheelUp:
		button_str = "Wheel Up"
		button_color = .BrightCyan
	case .WheelDown:
		button_str = "Wheel Down"
		button_color = .BrightMagenta
	}
	munin.print_at(buf, {16, y}, button_str, button_color)
	y += 2

	munin.print_at(buf, {2, y}, "Last Event:", .BrightYellow)
	event_str := ""
	event_color := munin.Basic_Color.White
	switch model.last_event {
	case .Press:
		event_str = "Press"
		event_color = .BrightGreen
	case .Release:
		event_str = "Release"
		event_color = .BrightRed
	case .Drag:
		event_str = "Drag"
		event_color = .BrightYellow
	case .Move:
		event_str = "Move"
		event_color = .BrightBlack
	}
	munin.print_at(buf, {15, y}, event_str, event_color)
	y += 2

	munin.print_at(buf, {2, y}, "Click Count:", .BrightYellow)
	munin.print_at(buf, {16, y}, fmt.tprintf("%d", model.click_count), .BrightMagenta)
	y += 1

	munin.print_at(buf, {2, y}, "Scroll Count:", .BrightYellow)
	munin.print_at(buf, {17, y}, fmt.tprintf("%d", model.scroll_count), .BrightCyan)
	munin.print_at(
		buf,
		{22, y},
		fmt.tprintf("(↑%d ↓%d)", model.scroll_up, model.scroll_down),
		.BrightBlack,
	)
	y += 2

	// Draw drag trail
	if len(model.drag_path) > 0 {
		munin.print_at(buf, {2, y}, "Drag Trail:", .BrightYellow)
		for point in model.drag_path {
			if point.x >= 0 &&
			   point.x < model.screen_width &&
			   point.y >= 0 &&
			   point.y < model.screen_height {
				munin.print_at(buf, point, "*", .BrightCyan)
			}
		}
		y += 1
	}

	// Draw cursor at mouse position
	if model.last_mouse_x >= 0 &&
	   model.last_mouse_x < model.screen_width &&
	   model.last_mouse_y >= 0 &&
	   model.last_mouse_y < model.screen_height {
		cursor_char := "+"
		cursor_color := munin.Basic_Color.BrightGreen

		switch model.last_button {
		case .Left:
			cursor_char = "L"
			cursor_color = .BrightGreen
		case .Right:
			cursor_char = "R"
			cursor_color = .BrightRed
		case .Middle:
			cursor_char = "M"
			cursor_color = .BrightYellow
		case .WheelUp:
			cursor_char = "^"
			cursor_color = .BrightCyan
		case .WheelDown:
			cursor_char = "v"
			cursor_color = .BrightMagenta
		case .None:
			cursor_char = "+"
			cursor_color = .BrightCyan
		}

		munin.set_bold(buf)
		munin.print_at(buf, {model.last_mouse_x, model.last_mouse_y}, cursor_char, cursor_color)
		munin.reset_style(buf)
	}

	// Instructions at bottom
	instructions_y := model.screen_height - 5
	munin.print_at(buf, {2, instructions_y}, "Instructions:", .BrightYellow)
	munin.print_at(buf, {2, instructions_y + 1}, "• Move mouse to track position", .White)
	munin.print_at(buf, {2, instructions_y + 2}, "• Click buttons to test events", .White)
	munin.print_at(buf, {2, instructions_y + 3}, "• Scroll wheel up/down", .White)
	munin.print_at(buf, {2, instructions_y + 4}, "• Hold and drag to draw trail", .White)
	munin.print_at(buf, {40, instructions_y + 1}, "• Press 'c' to clear counts", .White)
	munin.print_at(buf, {40, instructions_y + 2}, "• Press 'q' to quit", .White)
}

// 5. Define your Input handler
input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_input().?; ok {
		switch e in event {
		case munin.Key_Event:
			if e.key == .Char {
				switch e.char {
				case 'q', 'Q', 3:
					return Quit{}
				case 'c', 'C':
					return Key_Input{event = e}
				}
			}
		case munin.Mouse_Event:
			return Mouse_Input{event = e}
		}
	}
	return nil
}

// 6. Run your program
main :: proc() {
	program := munin.make_program(init, update, view)
	defer delete(program.model.drag_path)
	munin.run(&program, input_handler)
}
