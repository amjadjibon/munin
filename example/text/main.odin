package main

import munin "../../munin"
import "core:fmt"
import "core:strings"
import "core:mem"

// Simple text input example with inline mode
Model :: struct {
	text:            string,
	cursor_pos:      int,
	submitted_lines: [dynamic]string,
	allocator:       mem.Allocator,
}

init :: proc() -> Model {
	return Model{
		text            = "",
		cursor_pos      = 0,
		submitted_lines = make([dynamic]string),
		allocator       = context.allocator,
	}
}

AddChar :: struct {
	char: rune,
}
Backspace :: struct {}
Submit :: struct {}
Quit :: struct {}

Msg :: union {
	AddChar,
	Backspace,
	Submit,
	Quit,
}

update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case AddChar:
		// Add character to text
		new_text := fmt.aprintf("%s%c", model.text, m.char, allocator = model.allocator)
		delete(model.text, model.allocator)
		new_model.text = new_text
		new_model.cursor_pos += 1

	case Backspace:
		// Remove last character
		if len(model.text) > 0 {
			new_text := model.text[:len(model.text) - 1]
			new_model.text = strings.clone(new_text, model.allocator)
			delete(model.text, model.allocator)
			new_model.cursor_pos = max(0, model.cursor_pos - 1)
		}

	case Submit:
		// Submit current text and start new line
		if len(model.text) > 0 {
			// Save current text to submitted lines
			submitted := strings.clone(model.text, model.allocator)
			append(&new_model.submitted_lines, submitted)

			// Clear current text for new input
			delete(model.text, model.allocator)
			new_model.text = ""
			new_model.cursor_pos = 0
		}

	case Quit:
		should_quit = true
		// Clean up allocated text and submitted lines
		delete(model.text, model.allocator)
		for line in model.submitted_lines {
			delete(line, model.allocator)
		}
		delete(model.submitted_lines)
	}

	return new_model, should_quit
}

view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)

	// Title
	munin.draw_title(buf, {0, 1}, 80, "Text Input Demo", .BrightCyan, bold = true)

	// Display submitted lines
	if len(model.submitted_lines) > 0 {
		munin.print_at(buf, {2, 3}, "Submitted Lines:", .BrightGreen)
		for line, i in model.submitted_lines {
			munin.print_at(
				buf,
				{4, 4 + i},
				fmt.tprintf("%d. %s", i + 1, line),
				.Green,
			)
		}
	}

	// Current input line
	input_y := len(model.submitted_lines) > 0 ? 5 + len(model.submitted_lines) : 4
	munin.print_at(buf, {2, input_y}, "Current Input:", .BrightYellow)
	munin.print_at(buf, {2, input_y + 1}, "> ", .BrightYellow)
	munin.print_at(buf, {4, input_y + 1}, fmt.tprintf("%s_", model.text), .White)

	// Help text at bottom
	munin.print_at(
		buf,
		{2, input_y + 3},
		"Type to add • Enter to submit • Backspace to delete • q: quit",
		.BrightBlue,
	)
}

input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_key().?; ok {
		#partial switch event.key {
		case .Enter:
			return Submit{}
		case .Backspace:
			return Backspace{}
		case .Char:
			switch event.char {
			case 'q', 'Q', 3: // q, Q, or Ctrl+C
				return Quit{}
			case:
				// Add any printable character
				if event.char >= 32 && event.char < 127 {
					return AddChar{event.char}
				}
			}
		}
	}
	return nil
}

main :: proc() {
	// Set up memory tracking in debug mode
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

	program := munin.make_program(init, update, view)

	// Run in fullscreen mode with clear on exit
	munin.run(&program, input_handler, clear_on_exit = true)
}
