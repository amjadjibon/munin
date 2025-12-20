package main

import munin "../../munin"
import "core:strings"

Msg :: munin.Input_Event

Model :: struct {
	selected: int,
	items:    [dynamic]string,
}

init :: proc() -> Model {
	items := make([dynamic]string)
	append(&items, "🚀 Rocket Launch")
	append(&items, "🌈 Rainbow Colors")
	append(&items, "😀 Happy Face")
	append(&items, "🎉 Party Time")
	append(&items, "🧅 Onion Layer")
	append(&items, "💾 Save Data")

	return Model{selected = 0, items = items}
}

update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case munin.Key_Event:
		#partial switch m.key {
		case .Up:
			new_model.selected -= 1
			if new_model.selected < 0 {
				new_model.selected = len(model.items) - 1
			}
		case .Down:
			new_model.selected += 1
			if new_model.selected >= len(model.items) {
				new_model.selected = 0
			}
		case .Char:
			if m.char == 'q' {
				should_quit = true
			}
		case .Escape:
			should_quit = true
		}
	case munin.Mouse_Event:
	// Ignore mouse for now
	}

	return new_model, should_quit
}

view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)

	// Draw title
	munin.draw_title(buf, {0, 0}, 60, "Emoji Alignment Test", .BrightYellow, true)
	munin.print_at(buf, {2, 2}, "Press Up/Down to move selection. 'q' to quit.", .BrightBlack)

	// Draw Box
	munin.draw_box(buf, {4, 4}, 40, 10, .White)

	// Draw Items
	for item, i in model.items {
		y := 5 + i
		if y >= 13 {break} 	// Clip to box

		pos := munin.Vec2i{6, y}

		if i == model.selected {
			// Selected item
			munin.print_at(buf, {pos.x - 2, pos.y}, ">", .BrightCyan)
			munin.set_reverse(buf)
			munin.print_at(buf, pos, item, .BrightCyan)
			munin.reset_style(buf)
		} else {
			munin.print_at(buf, pos, item, .White)
		}
	}
}

input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_input().?; ok {
		return event
	}
	return nil
}

main :: proc() {
	program := munin.make_program(init, update, view)
	munin.run(&program, input_handler, clear_on_exit = true)
}
