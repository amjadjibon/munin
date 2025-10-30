package main

import munin "../../munin"
import comp "../../components"
import "core:fmt"
import "core:strings"

// 1. Define your Model
Model :: struct {
	screen_width:  int,
	screen_height: int,
	counter:       int,
	toggle_count:  int,
	program_ref:   rawptr, // Store reference to program for toggling
}

init :: proc() -> Model {
	return Model{
		screen_width = 80,
		screen_height = 24,
		counter = 0,
		toggle_count = 0,
		program_ref = nil,
	}
}

// 2. Define your Messages
Increment :: struct {}
Decrement :: struct {}
ToggleScreen :: struct {}
Quit :: struct {}

Msg :: union {
	Increment,
	Decrement,
	ToggleScreen,
	Quit,
}

// 3. Define your Update function
update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case Increment:
		new_model.counter += 1
	case Decrement:
		new_model.counter -= 1
	case ToggleScreen:
		// Toggle screen mode
		if new_model.program_ref != nil {
			program := (^munin.Program(Model, Msg))(new_model.program_ref)
			munin.toggle_screen_mode(program)
			new_model.toggle_count += 1
		}
	case Quit:
		should_quit = true
	}

	return new_model, should_quit
}

// 4. Define your View function
view :: proc(model: Model, buf: ^strings.Builder) {
	// Get current screen mode from program reference
	current_mode := munin.Screen_Mode.Fullscreen
	if model.program_ref != nil {
		program := (^munin.Program(Model, Msg))(model.program_ref)
		current_mode = program.screen_mode
	}

	munin.clear_screen(buf)

	// Title with current mode
	mode_str := current_mode == .Fullscreen ? "FULLSCREEN" : "INLINE"
	title := fmt.tprintf("SCREEN MODE DEMO - %s MODE", mode_str)
	comp.draw_banner(buf, {0, 0}, model.screen_width, title, .BrightBlue, .White)

	y := 2

	// Mode explanation
	munin.print_at(buf, {2, y}, "Current Mode:", .BrightYellow)
	y += 1

	if current_mode == .Fullscreen {
		munin.print_at(buf, {2, y}, "✓ Alternative Screen Buffer (Fullscreen)", .BrightGreen)
		y += 1
		munin.print_at(buf, {4, y}, "- Uses separate screen buffer", .White)
		y += 1
		munin.print_at(buf, {4, y}, "- Terminal content is preserved", .White)
		y += 1
		munin.print_at(buf, {4, y}, "- Clears screen on exit", .White)
	} else {
		munin.print_at(buf, {2, y}, "✓ Inline Mode", .BrightCyan)
		y += 1
		munin.print_at(buf, {4, y}, "- Runs in normal terminal buffer", .White)
		y += 1
		munin.print_at(buf, {4, y}, "- Output remains after exit", .White)
		y += 1
		munin.print_at(buf, {4, y}, "- Scrolls with terminal history", .White)
	}
	y += 2

	// Separator
	munin.print_at(buf, {0, y}, strings.repeat("─", model.screen_width), .BrightBlack)
	y += 2

	// Counter demo
	munin.print_at(buf, {2, y}, "Counter Demo:", .BrightYellow)
	y += 1
	munin.print_at(buf, {2, y}, "Value:", .White)
	munin.print_at(buf, {10, y}, fmt.tprintf("%d", model.counter), .BrightMagenta)
	y += 2

	// Toggle count
	munin.print_at(buf, {2, y}, "Mode Toggles:", .BrightYellow)
	munin.print_at(buf, {17, y}, fmt.tprintf("%d", model.toggle_count), .BrightCyan)
	y += 2

	// Info box
	munin.draw_box(buf, {2, y}, model.screen_width - 4, 8, .BrightYellow)
	munin.print_at(buf, {4, y}, "ℹ INFO", .BrightYellow)
	y += 1
	munin.print_at(buf, {4, y}, "Press 'f' to toggle between fullscreen and inline modes.", .White)
	y += 1
	munin.print_at(buf, {4, y}, "Watch how the behavior changes!", .White)
	y += 2
	munin.print_at(buf, {4, y}, "In Fullscreen: Clean exit, preserved terminal", .BrightGreen)
	y += 1
	munin.print_at(buf, {4, y}, "In Inline:     Output stays in terminal history", .BrightCyan)
	y += 2

	// Controls
	controls_y := model.screen_height - 7
	comp.draw_banner(buf, {0, controls_y}, model.screen_width, "CONTROLS", .BrightMagenta, .White)
	controls_y += 1

	munin.print_at(buf, {2, controls_y}, "Space", .BrightGreen)
	munin.print_at(buf, {12, controls_y}, "Increment counter", .White)
	controls_y += 1

	munin.print_at(buf, {2, controls_y}, "d", .BrightGreen)
	munin.print_at(buf, {12, controls_y}, "Decrement counter", .White)
	controls_y += 1

	munin.print_at(buf, {2, controls_y}, "f", .BrightYellow)
	munin.print_at(buf, {12, controls_y}, "Toggle screen mode (Fullscreen ↔ Inline)", .White)
	controls_y += 1

	munin.print_at(buf, {2, controls_y}, "q", .BrightRed)
	munin.print_at(buf, {12, controls_y}, "Quit", .White)
}

// 5. Define your Input handler
input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_input().?; ok {
		switch e in event {
		case munin.Key_Event:
			if e.key == .Char {
				switch e.char {
				case ' ':
					return Increment{}
				case 'd', 'D':
					return Decrement{}
				case 'f', 'F':
					return ToggleScreen{}
				case 'q', 'Q', 3: // q, Q, or Ctrl+C
					return Quit{}
				}
			}
		case munin.Mouse_Event:
			// Ignore mouse events in this demo
		}
	}
	return nil
}

// 6. Run your program
main :: proc() {
	program := munin.make_program(init, update, view)

	// Store program reference in model for toggle access
	program.model.program_ref = &program

	// Start in fullscreen mode (default)
	// You can also start with: munin.run(&program, input_handler, initial_mode = .Inline)
	munin.run(&program, input_handler)
}
