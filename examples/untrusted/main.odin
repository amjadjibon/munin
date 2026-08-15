package main

// Displaying data you did not write.
//
// A TUI mostly shows text that came from somewhere else: filenames, log lines,
// database rows, API responses. That text can contain escape sequences, and a
// terminal does not distinguish "text a program printed" from "commands a
// program sent" - so unfiltered, the data drives the terminal instead of just
// appearing in it. It can move the cursor, erase the screen, change the window
// title, or (with OSC 52, which this example deliberately does not include)
// write the user's clipboard.
//
// Truncation is not a defence: an escape sequence is zero cells wide, so it
// survives any column width.
//
// The data components - draw_table, draw_list, draw_tree, draw_input,
// draw_box_titled - strip escape sequences and control bytes by default. The
// low-level primitives (print_at, printf_at, draw_text_*) do not: they exist
// to emit exactly what the caller composed, so sanitize before handing them
// untrusted text.
//
// Press S to turn sanitizing off and watch the same data wreck the display.

import munin "../../munin"
import comp "../../munin/components"
import "core:fmt"
import "core:mem"
import "core:strings"

// ============================================================
// THE HOSTILE DATA
// ============================================================
//
// Pretend these came from a directory listing and a build log. Every payload
// here is visible but harmless - cursor moves, an erase, an unterminated
// colour, a window title.

FILES := [][]string {
	{"report.pdf", "12 KB", "ok"},
	{"notes\x1b[2J.txt", "3 KB", "erases the screen"},
	{"photo\x1b[12;40H.png", "1.2 MB", "jumps the cursor"},
	{"archive\x1b[41m.zip", "88 MB", "bleeds a background colour"},
	{"README\x1b]0;pwned\x07.md", "4 KB", "rewrites the window title"},
}

LOG_LINES := []string {
	"build started",
	"warning: unused variable\x1b[5;1H",
	"\x1b[32mlinking\x1b[0m",
	"error: undefined symbol \x1b[2K",
	"build failed",
}

// ============================================================
// MODEL
// ============================================================

Model :: struct {
	sanitize: bool,
	selected: int,
}

init :: proc() -> Model {
	return Model{sanitize = true, selected = 0}
}

Toggle :: struct {}
Next :: struct {}
Prev :: struct {}
Quit :: struct {}

Msg :: union {
	Toggle,
	Next,
	Prev,
	Quit,
}

update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	m := model

	switch _ in msg {
	case Toggle:
		m.sanitize = !m.sanitize
	case Next:
		m.selected = (m.selected + 1) % len(LOG_LINES)
	case Prev:
		m.selected = (m.selected - 1 + len(LOG_LINES)) % len(LOG_LINES)
	case Quit:
		return m, true
	}

	return m, false
}

// ============================================================
// VIEW
// ============================================================

view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)

	munin.set_bold(buf)
	munin.print_at(buf, {2, 1}, "Untrusted text", .BrightCyan)
	munin.reset_style(buf)

	state := model.sanitize ? "ON" : "OFF"
	state_color :=
		model.sanitize ? munin.Basic_Color.BrightGreen : munin.Basic_Color.BrightRed
	munin.print_at(buf, {2, 2}, "sanitize:", .BrightBlack)
	munin.print_at(buf, {12, 2}, state, state_color)
	munin.print_at(
		buf,
		{18, 2},
		model.sanitize ? "data is drawn as text" : "data is driving your terminal",
		.BrightBlack,
	)

	// A table of "filenames". Every component that displays data takes
	// `sanitize`, defaulting to true; this example makes it a runtime toggle
	// so the difference is visible.
	columns := []comp.Table_Column {
		{title = "name", width = 26, align = .Left},
		{title = "size", width = 8, align = .Right},
		{title = "payload", width = 28, align = .Left},
	}
	comp.draw_table(buf, {2, 4}, columns, FILES, .BrightCyan, .White, model.sanitize)

	// A list of "log lines".
	items := make([dynamic]comp.List_Item, context.temp_allocator)
	for line in LOG_LINES {
		append(&items, comp.List_Item{text = line, color = .White})
	}
	munin.print_at(buf, {2, 13}, "build log", .BrightYellow)
	comp.draw_list(
		buf,
		{2, 14},
		items[:],
		model.selected,
		.Arrow,
		"",
		.BrightYellow,
		2,
		model.sanitize,
	)

	// print_at is a primitive: it emits exactly what it is given, so the
	// caller sanitizes. Without this call the same payload would land here
	// too.
	detail := LOG_LINES[model.selected]
	if model.sanitize {
		detail = munin.sanitize_display(detail)
	}
	munin.print_at(buf, {2, 21}, "selected:", .BrightBlack)
	munin.print_at(buf, {12, 21}, detail, .White)

	munin.print_at(buf, {2, 23}, "S: toggle sanitizing   UP/DOWN: select   Q: quit", .BrightBlue)
}

input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_key().?; ok {
		#partial switch event.key {
		case .Up:
			return Prev{}
		case .Down:
			return Next{}
		case .Char:
			switch event.char {
			case 's', 'S':
				return Toggle{}
			case 'q', 'Q':
				return Quit{}
			case 'c':
				if event.ctrl {
					return Quit{}
				}
			}
		}
	}
	return nil
}

main :: proc() {
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
	munin.run(&program, input_handler)
}
