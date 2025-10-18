package main

import munin "../../munin"
import comp "../../components"
import "core:strings"

// 1. Define your Model
Model :: struct {
	screen_width:  int,
	screen_height: int,
}

init :: proc() -> Model {
	return Model{screen_width = 80, screen_height = 24}
}

// 2. Define your Messages
Quit :: struct {}

Msg :: union {
	Quit,
}

// 3. Define your Update function
update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case Quit:
		should_quit = true
	}

	return new_model, should_quit
}

// 4. Define your View function
view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)

	y := 1

	// Draw banner
	comp.draw_banner(buf, {0, y}, model.screen_width, "TEXT COMPONENTS DEMO", .BrightBlue, .White)
	y += 2

	// Draw heading
	comp.draw_heading(buf, {2, y}, "Text Component Examples", 1, .BrightCyan)
	y += 3

	// Draw label-value pairs
	comp.draw_label_value(buf, {2, y}, "Name", "Munin Framework", .BrightYellow, .White, ": ")
	y += 1
	comp.draw_label_value(buf, {2, y}, "Language", "Odin", .BrightYellow, .BrightGreen, ": ")
	y += 1
	comp.draw_label_value(buf, {2, y}, "Version", "1.0.0", .BrightYellow, .BrightMagenta, ": ")
	y += 2

	// Draw heading level 2 (no underline)
	comp.draw_heading(buf, {2, y}, "Word Wrapping Demo", 2, .BrightYellow)
	y += 2

	// Draw wrapped text
	long_text := "The Munin framework is a Terminal UI library for Odin inspired by The Elm Architecture. It provides a clean way to build interactive terminal applications with immutable state updates and functional composition."
	lines_used := comp.draw_text_wrapped(buf, {2, y}, model.screen_width - 4, long_text, .White)
	y += lines_used + 1

	// Draw centered text
	comp.draw_text_centered(buf, y, model.screen_width, "This text is centered!", .BrightCyan)
	y += 2

	// Draw another banner
	comp.draw_banner(buf, {0, y}, model.screen_width, "Press 'q' or Ctrl+C to quit", .BrightMagenta, .White)

	// Instructions at bottom
	munin.print_at(buf, {2, model.screen_height - 2}, "Controls: q or Ctrl+C to quit", .BrightBlack)
}

// 5. Define your Input handler
input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_key().?; ok {
		if event.key == .Char {
			switch event.char {
			case 'q', 'Q', 3:
				// q, Q, or Ctrl+C
				return Quit{}
			}
		}
	}
	return nil
}

// 6. Run your program
main :: proc() {
	program := munin.make_program(init, update, view)
	munin.run(&program, input_handler)
}
