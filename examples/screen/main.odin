package main

// The cell buffer: putting positioned components where you want them.
//
// Components like draw_table, draw_list and draw_box_titled paint with
// absolute cursor moves. On their own that means they always land at the
// coordinates they were given, they cannot be measured or padded, and drawing
// past the edge of the terminal wraps and corrupts whatever is next to it.
//
// A munin.Screen fixes both: paint a component into a grid with an origin and
// a clip size, and it lands inside that region with everything outside it
// dropped. Several components painted into one grid compose - which is what
// this example does, laying three of them out side by side and letting you
// shrink their regions until they clip.
//
// Run with `render_mode = .Cell_Diff` and the same grid is also used to send
// only the cells that changed each frame.

import munin "../../munin"
import comp "../../munin/components"
import "core:fmt"
import "core:mem"
import "core:strings"

// ============================================================
// MODEL
// ============================================================

Model :: struct {
	// Width of each of the three regions. Shrinking one clips its contents
	// rather than letting them spill into its neighbour.
	region_w: int,
	region_h: int,
	selected: int,
	gap:      int,
}

init :: proc() -> Model {
	return Model{region_w = 26, region_h = 9, selected = 0, gap = 2}
}

// ============================================================
// MESSAGES
// ============================================================

Widen :: struct {}
Narrow :: struct {}
Taller :: struct {}
Shorter :: struct {}
Select_Next :: struct {}
Quit :: struct {}

Msg :: union {
	Widen,
	Narrow,
	Taller,
	Shorter,
	Select_Next,
	Quit,
}

update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	m := model

	switch _ in msg {
	case Widen:
		m.region_w = min(m.region_w + 2, 40)
	case Narrow:
		m.region_w = max(m.region_w - 2, 4) // keep going: it will clip
	case Taller:
		m.region_h = min(m.region_h + 1, 14)
	case Shorter:
		m.region_h = max(m.region_h - 1, 2)
	case Select_Next:
		m.selected = (m.selected + 1) % 3
	case Quit:
		return m, true
	}

	return m, false
}

// ============================================================
// VIEW
// ============================================================

// Each of these draws at {0,0} and knows nothing about the others.

draw_panel_box :: proc(buf: ^strings.Builder, selected: bool) {
	color := selected ? munin.Basic_Color.BrightGreen : munin.Basic_Color.BrightBlue
	comp.draw_box_titled(buf, {0, 0}, 26, 9, " Box ", .Rounded, color, .BrightWhite)
	munin.print_at(buf, {2, 2}, "positioned component", .White)
	munin.print_at(buf, {2, 3}, "drawn at 0,0", .BrightBlack)
	munin.print_at(buf, {2, 5}, "clipped to its", .BrightBlack)
	munin.print_at(buf, {2, 6}, "own region", .BrightBlack)
}

draw_panel_table :: proc(buf: ^strings.Builder, selected: bool) {
	color := selected ? munin.Basic_Color.BrightGreen : munin.Basic_Color.BrightBlue
	columns := []comp.Table_Column {
		{title = "id", width = 4, align = .Right},
		{title = "name", width = 12, align = .Left},
	}
	rows := [][]string{{"1", "alpha"}, {"2", "beta"}, {"3", "gamma"}, {"4", "delta"}}
	comp.draw_table(buf, {0, 0}, columns, rows, .BrightCyan, color)
}

draw_panel_list :: proc(buf: ^strings.Builder, selected: bool, highlight: int) {
	color := selected ? munin.Basic_Color.BrightGreen : munin.Basic_Color.BrightBlue
	comp.draw_box_styled(buf, {0, 0}, 24, 9, .Rounded, color)
	items := []comp.List_Item {
		{text = "composition", color = .White},
		{text = "clipping", color = .White},
		{text = "diffing", color = .White},
		{text = "wide chars 你好", color = .White},
	}
	comp.draw_list(buf, {2, 2}, items, highlight, .Bullet)
}

// Render one component into its own builder, so it can be painted into a
// region of the screen.
render_into :: proc(draw: proc(buf: ^strings.Builder, selected: bool), selected: bool) -> string {
	b := strings.builder_make(context.temp_allocator)
	draw(&b, selected)
	return strings.to_string(b)
}

view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)

	term_w, term_h, ok := munin.get_window_size()
	if !ok {
		term_w, term_h = 80, 24
	}

	// The grid everything is composed into. It lives in the temp arena, which
	// the run loop resets each frame.
	screen := munin.screen_make(term_w, term_h, context.temp_allocator)

	origin_y := 4
	x := 2

	// Three independently drawn components, each painted into its own region.
	// Without the origin and clip they would all land at 0,0 and overwrite
	// each other; with them they compose.
	munin.screen_paint(
		&screen,
		render_into(draw_panel_box, model.selected == 0),
		{x, origin_y},
		{model.region_w, model.region_h},
	)
	x += model.region_w + model.gap

	table := strings.builder_make(context.temp_allocator)
	draw_panel_table(&table, model.selected == 1)
	munin.screen_paint(
		&screen,
		strings.to_string(table),
		{x, origin_y},
		{model.region_w, model.region_h},
	)
	x += model.region_w + model.gap

	list := strings.builder_make(context.temp_allocator)
	draw_panel_list(&list, model.selected == 2, model.selected == 2 ? 1 : -1)
	munin.screen_paint(
		&screen,
		strings.to_string(list),
		{x, origin_y},
		{model.region_w, model.region_h},
	)

	// Header and footer go straight into the grid too.
	header := strings.builder_make(context.temp_allocator)
	munin.set_bold(&header)
	munin.print_at(&header, {2, 1}, "Cell buffer", .BrightCyan)
	munin.reset_style(&header)
	munin.print_at(
		&header,
		{2, 2},
		fmt.tprintf(
			"three positioned components composed into one grid   region: %dx%d",
			model.region_w,
			model.region_h,
		),
		.BrightBlack,
	)
	munin.print_at(
		&header,
		{2, origin_y + model.region_h + 1},
		"< >: narrower/wider   - +: shorter/taller   TAB: select   Q: quit",
		.BrightBlue,
	)
	munin.print_at(
		&header,
		{2, origin_y + model.region_h + 2},
		"shrink a region past its contents to watch it clip instead of overflow",
		.BrightBlack,
	)
	munin.screen_paint(&screen, strings.to_string(header))

	// Finally, turn the grid into terminal output.
	munin.screen_render(&screen, buf)
}

// ============================================================
// INPUT
// ============================================================

input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_key().?; ok {
		#partial switch event.key {
		case .Tab:
			return Select_Next{}
		case .Left:
			return Narrow{}
		case .Right:
			return Widen{}
		case .Up:
			return Taller{}
		case .Down:
			return Shorter{}
		case .Char:
			switch event.char {
			case '<', ',':
				return Narrow{}
			case '>', '.':
				return Widen{}
			case '-':
				return Shorter{}
			case '+', '=':
				return Taller{}
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

	// The view composes its own grid, and the run loop keeps a second one to
	// diff against: only changed cells go to the terminal.
	munin.run(&program, input_handler, render_mode = .Cell_Diff)
}
