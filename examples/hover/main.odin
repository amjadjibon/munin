package main

import comp "../../munin/components"
import munin "../../munin"
import "core:fmt"
import "core:strings"

// 1. Define your Model
Button :: struct {
	x, y:        int,
	width:       int,
	label:       string,
	hovered:     bool,
	clicked:     bool,
	click_count: int,
}

Model :: struct {
	screen_width:  int,
	screen_height: int,
	mouse_x:       int,
	mouse_y:       int,
	buttons:       [4]Button,
	hover_trail:   [dynamic]munin.Vec2i,
	show_trail:    bool,
}

init :: proc() -> Model {
	buttons := [4]Button {
		{x = 10, y = 5, width = 20, label = "Button 1"},
		{x = 35, y = 5, width = 20, label = "Button 2"},
		{x = 10, y = 9, width = 20, label = "Button 3"},
		{x = 35, y = 9, width = 20, label = "Button 4"},
	}

	return Model {
		screen_width = 80,
		screen_height = 24,
		mouse_x = -1,
		mouse_y = -1,
		buttons = buttons,
		hover_trail = make([dynamic]munin.Vec2i),
		show_trail = false,
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

// Helper to check if point is inside button
is_point_in_button :: proc(x, y: int, btn: Button) -> bool {
	return x >= btn.x && x < btn.x + btn.width && y >= btn.y && y < btn.y + 3
}

// 3. Define your Update function
update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case Mouse_Input:
		new_model.mouse_x = m.event.x
		new_model.mouse_y = m.event.y

		// Update hover state for all buttons
		for &btn in new_model.buttons {
			btn.hovered = is_point_in_button(m.event.x, m.event.y, btn)

			// Handle clicks
			if btn.hovered && m.event.type == .Press && m.event.button == .Left {
				btn.clicked = true
				btn.click_count += 1
			} else if m.event.type == .Release {
				btn.clicked = false
			}
		}

		// Track hover trail
		if new_model.show_trail && m.event.type == .Move {
			append(&new_model.hover_trail, munin.Vec2i{m.event.x, m.event.y})
			// Limit trail length
			if len(new_model.hover_trail) > 200 {
				ordered_remove(&new_model.hover_trail, 0)
			}
		}

	case Key_Input:
		if m.event.key == .Char {
			switch m.event.char {
			case 'q', 'Q', 3:
				// q, Q, or Ctrl+C
				should_quit = true
			case 't', 'T':
				// Toggle trail
				new_model.show_trail = !new_model.show_trail
				if !new_model.show_trail {
					clear(&new_model.hover_trail)
				}
			case 'c', 'C':
				// Clear click counts
				for &btn in new_model.buttons {
					btn.click_count = 0
				}
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
	comp.draw_banner(
		buf,
		{0, 0},
		model.screen_width,
		"HOVER DEMO - Interactive Buttons",
		.BrightBlue,
		.White,
	)

	// Instructions
	y := 2
	munin.print_at(buf, {2, y}, "Hover over buttons to see them highlight!", .BrightYellow)
	y += 1

	// Draw buttons
	for btn in model.buttons {
		bg_color := munin.Basic_Color.Blue
		text_color := munin.Basic_Color.White
		border_char := "─"

		if btn.clicked {
			bg_color = .BrightRed
			text_color = .White
			border_char = "═"
		} else if btn.hovered {
			bg_color = .BrightGreen
			text_color = .Black
			border_char = "━"
		}

		// Draw button box
		// Top border
		munin.move_cursor(buf, {btn.x, btn.y})
		munin.set_color(buf, bg_color)
		strings.write_string(buf, "┌")
		for i in 0 ..< btn.width - 2 {
			strings.write_string(buf, border_char)
		}
		strings.write_string(buf, "┐")
		munin.reset_style(buf)

		// Middle with text
		munin.move_cursor(buf, {btn.x, btn.y + 1})
		munin.set_bg_color(buf, bg_color)
		munin.set_color(buf, text_color)
		munin.set_bold(buf)
		strings.write_string(buf, "│")

		// Center text
		padding := (btn.width - 2 - len(btn.label)) / 2
		for i in 0 ..< padding {
			strings.write_byte(buf, ' ')
		}
		strings.write_string(buf, btn.label)
		for i in 0 ..< (btn.width - 2 - len(btn.label) - padding) {
			strings.write_byte(buf, ' ')
		}
		strings.write_string(buf, "│")
		munin.reset_style(buf)

		// Bottom border
		munin.move_cursor(buf, {btn.x, btn.y + 2})
		munin.set_color(buf, bg_color)
		strings.write_string(buf, "└")
		for i in 0 ..< btn.width - 2 {
			strings.write_string(buf, border_char)
		}
		strings.write_string(buf, "┘")
		munin.reset_style(buf)

		// Show click count below button
		if btn.click_count > 0 {
			munin.print_at(
				buf,
				{btn.x + btn.width / 2 - 4, btn.y + 3},
				fmt.tprintf("Clicks: %d", btn.click_count),
				.BrightMagenta,
			)
		}
	}

	// Draw hover trail if enabled
	if model.show_trail {
		for point, i in model.hover_trail {
			if point.x >= 0 &&
			   point.x < model.screen_width &&
			   point.y >= 0 &&
			   point.y < model.screen_height {
				// Fade trail (older = darker)
				color := munin.Basic_Color.BrightBlack
				if i > len(model.hover_trail) - 50 {
					color = .BrightCyan
				} else if i > len(model.hover_trail) - 100 {
					color = .Cyan
				}
				munin.print_at(buf, point, "·", color)
			}
		}
	}

	// Mouse cursor
	if model.mouse_x >= 0 &&
	   model.mouse_x < model.screen_width &&
	   model.mouse_y >= 0 &&
	   model.mouse_y < model.screen_height {
		munin.set_bold(buf)
		munin.print_at(buf, {model.mouse_x, model.mouse_y}, "⊕", .BrightYellow)
		munin.reset_style(buf)
	}

	// Status area
	status_y := 14
	munin.print_at(buf, {2, status_y}, "Status:", .BrightYellow)
	status_y += 1

	munin.print_at(
		buf,
		{2, status_y},
		fmt.tprintf("Mouse Position: (%d, %d)", model.mouse_x, model.mouse_y),
		.White,
	)
	status_y += 1

	hovered_button := -1
	for btn, i in model.buttons {
		if btn.hovered {
			hovered_button = i + 1
			break
		}
	}

	if hovered_button > 0 {
		munin.print_at(
			buf,
			{2, status_y},
			fmt.tprintf("Hovering: Button %d", hovered_button),
			.BrightGreen,
		)
	} else {
		munin.print_at(buf, {2, status_y}, "Hovering: None", .BrightBlack)
	}
	status_y += 1

	trail_status := "OFF" if !model.show_trail else "ON"
	trail_color := munin.Basic_Color.BrightBlack if !model.show_trail else .BrightCyan
	munin.print_at(buf, {2, status_y}, fmt.tprintf("Hover Trail: %s", trail_status), trail_color)

	// Controls at bottom
	controls_y := model.screen_height - 4
	munin.print_at(buf, {2, controls_y}, "Controls:", .BrightYellow)
	munin.print_at(buf, {2, controls_y + 1}, "• Move mouse to hover over buttons", .White)
	munin.print_at(buf, {2, controls_y + 2}, "• Click buttons to interact", .White)
	munin.print_at(buf, {40, controls_y + 1}, "• Press 't' to toggle trail", .White)
	munin.print_at(buf, {40, controls_y + 2}, "• Press 'c' to clear counts", .White)
	munin.print_at(buf, {40, controls_y + 3}, "• Press 'q' to quit", .White)
}

// 5. Define your Input handler
input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_input().?; ok {
		switch e in event {
		case munin.Key_Event:
			return Key_Input{event = e}
		case munin.Mouse_Event:
			return Mouse_Input{event = e}
		}
	}
	return nil
}

// 6. Run your program
main :: proc() {
	program := munin.make_program(init, update, view)
	defer delete(program.model.hover_trail)
	munin.run(&program, input_handler)
}
