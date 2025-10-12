package main

import munin "../../munin"
import "core:fmt"
import "core:strings"

// 1. Define your Model
Model :: struct {
	counter: int,
}

init :: proc() -> Model {
	return Model{counter = 0}
}

// 2. Define your Messages
Increment :: struct {}
Decrement :: struct {}
Quit :: struct {}

Msg :: union {
	Increment,
	Decrement,
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
	case Quit:
		should_quit = true
	}

	return new_model, should_quit
}

// 4. Define your View function
view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)
	munin.print_at(buf, {2, 2}, fmt.tprintf("Counter: "), .BrightGreen)
	munin.print_at(buf, {11, 2}, fmt.tprintf("%d", model.counter), .BrightRed)
	munin.print_at(buf, {2, 4}, "Press space to increment, d to decrement, q to quit", .White)
}

// 5. Define your Input handler
input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_key().?; ok {
		if event.key == .Char {
			switch event.char {
			case ' ':
				return Increment{}
			case 'd':
				return Decrement{}
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
