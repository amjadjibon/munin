package main

import munin "../../munin"
import "core:fmt"
import "core:strings"

// Simple inline counter example with mode toggling
Model :: struct {
	counter:     int,
	altscreen:   bool,
	program_ref: rawptr, // Store reference to program for toggling
}

init :: proc() -> Model {
	return Model{counter = 0, altscreen = false}
}

Increment :: struct {}
Decrement :: struct {}
ToggleMode :: struct {}
Quit :: struct {}

Msg :: union {
	Increment,
	Decrement,
	ToggleMode,
	Quit,
}

update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case Increment:
		new_model.counter += 1
	case Decrement:
		new_model.counter -= 1
	case ToggleMode:
		// Toggle screen mode
		if new_model.program_ref != nil {
			program := (^munin.Program(Model, Msg))(new_model.program_ref)
			munin.toggle_screen_mode(program)
			new_model.altscreen = !model.altscreen
		}
	case Quit:
		should_quit = true
	}

	return new_model, should_quit
}

// View function - works in both inline and fullscreen modes
view :: proc(model: Model, buf: ^strings.Builder) {
	// Clear screen only in fullscreen mode
	if model.altscreen {
		munin.clear_screen(buf)
	}

	// Display current mode
	strings.write_string(buf, "\n\n")
	munin.set_color(buf, .BrightYellow)
	mode_text := model.altscreen ? " FULLSCREEN MODE " : " INLINE MODE "
	strings.write_string(buf, fmt.tprintf("  You're in%s", mode_text))
	munin.reset_style(buf)
	strings.write_string(buf, "\n\n")

	// Display counter
	munin.set_color(buf, .BrightCyan)
	strings.write_string(buf, fmt.tprintf("  Counter: %d", model.counter))
	munin.reset_style(buf)
	strings.write_string(buf, "\n\n")

	// Help text
	munin.set_color(buf, .BrightBlue)
	strings.write_string(buf, "  space: increment • d: decrement • f: toggle mode • q: quit")
	munin.reset_style(buf)
	strings.write_string(buf, "\n\n")
}

input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_key().?; ok {
		if event.key == .Char {
			switch event.char {
			case ' ':
				return Increment{}
			case 'd', 'D':
				return Decrement{}
			case 'f', 'F':
				return ToggleMode{}
			case 'q', 'Q', 3:
				return Quit{}
			}
		}
	}
	return nil
}

main :: proc() {
	program := munin.make_program(init, update, view)

	// Store program reference in model for toggle access
	program.model.program_ref = &program

	// Start in inline mode with clear on exit
	munin.run(&program, input_handler, initial_mode = .Inline, clear_on_exit = true)
}
