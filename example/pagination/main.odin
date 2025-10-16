package main

import comp "../../components"
import munin "../../munin"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:time"

// Model holds the application state
Model :: struct {
	current_demo:   int,
	show_help:      bool,
	// Pagination state for demos
	current_page:   int,
	items_per_page: int,
	total_items:    int,
}

// Initialize model
init :: proc() -> Model {
	return Model{
		current_demo   = 0,
		show_help      = false,
		current_page   = 1,
		items_per_page = 10,
		total_items    = 147, // Example: 147 items
	}
}

// Messages
Quit :: struct {}
NextDemo :: struct {}
PrevDemo :: struct {}
ToggleHelp :: struct {}
NextPage :: struct {}
PrevPage :: struct {}
FirstPage :: struct {}
LastPage :: struct {}

Msg :: union {
	Quit,
	NextDemo,
	PrevDemo,
	ToggleHelp,
	NextPage,
	PrevPage,
	FirstPage,
	LastPage,
}

// Update function
update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case Quit:
		should_quit = true
	case NextDemo:
		new_model.current_demo = (model.current_demo + 1) % 6
		new_model.current_page = 1 // Reset page when switching demos
	case PrevDemo:
		new_model.current_demo = (model.current_demo - 1 + 6) % 6
		new_model.current_page = 1 // Reset page when switching demos
	case ToggleHelp:
		new_model.show_help = !model.show_help
	case NextPage:
		total_pages := comp.calculate_pages(model.total_items, model.items_per_page)
		new_model.current_page = min(model.current_page + 1, total_pages)
	case PrevPage:
		new_model.current_page = max(model.current_page - 1, 1)
	case FirstPage:
		new_model.current_page = 1
	case LastPage:
		total_pages := comp.calculate_pages(model.total_items, model.items_per_page)
		new_model.current_page = total_pages
	}

	return new_model, should_quit
}

// View function
view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)
	munin.set_window_title(buf, "Pagination Component Examples")

	// Header
	title := "Pagination Component Examples"
	munin.draw_title(buf, {0, 1}, 80, title, .BrightCyan)

	// Demo navigation
	munin.print_at(buf, {2, 3}, "Demos:", .BrightWhite)
	demos := []string{"Numbers", "Arrows", "Dots", "Compact", "With Info", "Table"}

	for i in 0 ..< len(demos) {
		color := munin.Color.White
		if i == model.current_demo {
			color = .BrightYellow
		}
		item_display := fmt.tprintf("[%d] %s", i + 1, demos[i])
		munin.print_at(buf, {12 + i * 13, 3}, item_display, color)
	}

	// Current demo description
	descriptions := []string{
		"Standard numbered pagination with ellipsis",
		"Simple arrow-based navigation with page count",
		"Visual dot indicators for pages",
		"Compact text-based pagination display",
		"Pagination with item range information",
		"Real-world example: paginated data table",
	}

	desc_x := max(2, (80 - len(descriptions[model.current_demo])) / 2)
	munin.print_at(buf, {desc_x, 5}, descriptions[model.current_demo], .BrightGreen)

	// Current page info
	total_pages := comp.calculate_pages(model.total_items, model.items_per_page)
	page_info := fmt.tprintf("Current Page: %d/%d", model.current_page, total_pages)
	munin.print_at(buf, {2, 7}, page_info, .BrightBlue)

	// Draw current demo
	draw_demo(buf, model)

	// Help
	if model.show_help {
		draw_help(buf)
	} else {
		munin.print_at(buf, {2, 28}, "Press 'h' for help", .BrightYellow)
	}
}

// Draw help
draw_help :: proc(buf: ^strings.Builder) {
	help_y := 22
	comp.draw_box_styled(buf, {20, help_y}, 40, 8, .Double, .BrightYellow)
	munin.print_at(buf, {35, help_y}, " HELP ", .BrightWhite)

	munin.print_at(buf, {22, help_y + 1}, "← →     : Switch demos", .White)
	munin.print_at(buf, {22, help_y + 2}, "1-6     : Jump to demo", .White)
	munin.print_at(buf, {22, help_y + 3}, "n/p     : Next/Previous page", .White)
	munin.print_at(buf, {22, help_y + 4}, "f/l     : First/Last page", .White)
	munin.print_at(buf, {22, help_y + 5}, "h       : Toggle help", .White)
	munin.print_at(buf, {22, help_y + 6}, "q       : Quit", .White)
}

// Draw the current demo
draw_demo :: proc(buf: ^strings.Builder, model: Model) {
	demo_y := 10

	total_pages := comp.calculate_pages(model.total_items, model.items_per_page)

	switch model.current_demo {
	case 0:
		draw_numbers_pagination(buf, {5, demo_y}, model.current_page, total_pages)
	case 1:
		draw_arrows_pagination(buf, {5, demo_y}, model.current_page, total_pages)
	case 2:
		draw_dots_pagination(buf, {5, demo_y}, model.current_page, total_pages)
	case 3:
		draw_compact_pagination(buf, {5, demo_y}, model.current_page, total_pages)
	case 4:
		draw_pagination_with_info(
			buf,
			{5, demo_y},
			model.current_page,
			total_pages,
			model.items_per_page,
			model.total_items,
		)
	case 5:
		draw_table_with_pagination(
			buf,
			{5, demo_y},
			model.current_page,
			model.items_per_page,
			model.total_items,
		)
	}
}

// Demo 1: Numbers style pagination
draw_numbers_pagination :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	current_page: int,
	total_pages: int,
) {
	munin.print_at(buf, {pos.x, pos.y - 1}, "Numbers Style Pagination:", .BrightCyan)

	// Description
	desc := "Standard numbered pagination with ellipsis for many pages"
	munin.print_at(buf, {pos.x, pos.y + 1}, desc, .White)

	// Example with different max_visible values
	munin.print_at(buf, {pos.x, pos.y + 3}, "Max 7 visible pages (default):", .BrightYellow)
	comp.draw_pagination(buf, {pos.x, pos.y + 4}, current_page, total_pages, .Numbers, 7)

	munin.print_at(buf, {pos.x, pos.y + 6}, "Max 5 visible pages:", .BrightYellow)
	comp.draw_pagination(buf, {pos.x, pos.y + 7}, current_page, total_pages, .Numbers, 5)

	munin.print_at(buf, {pos.x, pos.y + 9}, "Max 3 visible pages:", .BrightYellow)
	comp.draw_pagination(buf, {pos.x, pos.y + 10}, current_page, total_pages, .Numbers, 3)
}

// Demo 2: Arrows style pagination
draw_arrows_pagination :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	current_page: int,
	total_pages: int,
) {
	munin.print_at(buf, {pos.x, pos.y - 1}, "Arrows Style Pagination:", .BrightCyan)

	// Description
	desc := "Simple arrow-based navigation with current/total page display"
	munin.print_at(buf, {pos.x, pos.y + 1}, desc, .White)

	// Examples at different positions
	munin.print_at(buf, {pos.x, pos.y + 4}, "Compact arrow navigation:", .BrightYellow)
	comp.draw_pagination(buf, {pos.x, pos.y + 5}, current_page, total_pages, .Arrows)

	// Show at first, middle, and last page states
	munin.print_at(buf, {pos.x, pos.y + 7}, "First page (← disabled):", .BrightYellow)
	comp.draw_pagination(buf, {pos.x, pos.y + 8}, 1, total_pages, .Arrows)

	munin.print_at(buf, {pos.x, pos.y + 10}, "Last page (→ disabled):", .BrightYellow)
	comp.draw_pagination(buf, {pos.x, pos.y + 11}, total_pages, total_pages, .Arrows)
}

// Demo 3: Dots style pagination
draw_dots_pagination :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	current_page: int,
	total_pages: int,
) {
	munin.print_at(buf, {pos.x, pos.y - 1}, "Dots Style Pagination:", .BrightCyan)

	// Description
	desc := "Visual dot indicators - best for small number of pages"
	munin.print_at(buf, {pos.x, pos.y + 1}, desc, .White)

	// Example with reasonable number of pages
	small_pages := 8
	munin.print_at(
		buf,
		{pos.x, pos.y + 4},
		fmt.tprintf("8 pages (page %d):", min(current_page, small_pages)),
		.BrightYellow,
	)
	comp.draw_pagination(
		buf,
		{pos.x, pos.y + 5},
		min(current_page, small_pages),
		small_pages,
		.Dots,
	)

	munin.print_at(buf, {pos.x, pos.y + 7}, "5 pages (page 3):", .BrightYellow)
	comp.draw_pagination(buf, {pos.x, pos.y + 8}, 3, 5, .Dots)

	munin.print_at(buf, {pos.x, pos.y + 10}, "Note:", .BrightRed)
	munin.print_at(
		buf,
		{pos.x, pos.y + 11},
		"Dots style works best with 10 or fewer pages",
		.White,
	)
}

// Demo 4: Compact style pagination
draw_compact_pagination :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	current_page: int,
	total_pages: int,
) {
	munin.print_at(buf, {pos.x, pos.y - 1}, "Compact Style Pagination:", .BrightCyan)

	// Description
	desc := "Text-based display with prev/next hints"
	munin.print_at(buf, {pos.x, pos.y + 1}, desc, .White)

	// Examples
	munin.print_at(buf, {pos.x, pos.y + 4}, "Standard compact view:", .BrightYellow)
	comp.draw_pagination(buf, {pos.x, pos.y + 5}, current_page, total_pages, .Compact)

	munin.print_at(buf, {pos.x, pos.y + 7}, "First page (no Prev):", .BrightYellow)
	comp.draw_pagination(buf, {pos.x, pos.y + 8}, 1, total_pages, .Compact)

	munin.print_at(buf, {pos.x, pos.y + 10}, "Last page (no Next):", .BrightYellow)
	comp.draw_pagination(buf, {pos.x, pos.y + 11}, total_pages, total_pages, .Compact)
}

// Demo 5: Pagination with item info
draw_pagination_with_info :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	current_page: int,
	total_pages: int,
	items_per_page: int,
	total_items: int,
) {
	munin.print_at(buf, {pos.x, pos.y - 1}, "Pagination with Item Info:", .BrightCyan)

	// Description
	desc := "Shows pagination controls with item range information"
	munin.print_at(buf, {pos.x, pos.y + 1}, desc, .White)

	// Example
	munin.print_at(
		buf,
		{pos.x, pos.y + 4},
		fmt.tprintf("Displaying %d items per page:", items_per_page),
		.BrightYellow,
	)
	comp.draw_pagination_with_info(
		buf,
		{pos.x, pos.y + 5},
		current_page,
		total_pages,
		items_per_page,
		total_items,
		.Numbers,
	)

	// Different style
	munin.print_at(buf, {pos.x, pos.y + 9}, "With arrows style:", .BrightYellow)
	comp.draw_pagination_with_info(
		buf,
		{pos.x, pos.y + 10},
		current_page,
		total_pages,
		items_per_page,
		total_items,
		.Arrows,
	)
}

// Demo 6: Table with pagination
draw_table_with_pagination :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	current_page: int,
	items_per_page: int,
	total_items: int,
) {
	munin.print_at(buf, {pos.x, pos.y - 1}, "Paginated Data Table:", .BrightCyan)

	// Generate sample data
	all_users := make([]User, total_items, context.temp_allocator)
	for i in 0 ..< total_items {
		all_users[i] = User{
			id    = i + 1,
			name  = fmt.tprintf("User %d", i + 1),
			email = fmt.tprintf("user%d@example.com", i + 1),
			role  = i % 3 == 0 ? "Admin" : (i % 3 == 1 ? "User" : "Guest"),
		}
	}

	// Get current page slice
	page_users := comp.get_page_slice(all_users[:], current_page, items_per_page)

	// Draw table
	columns := []comp.Table_Column{
		{title = "ID", width = 6, align = .Center},
		{title = "Name", width = 15, align = .Left},
		{title = "Email", width = 25, align = .Left},
		{title = "Role", width = 10, align = .Center},
	}

	rows := make([][]string, len(page_users), context.temp_allocator)
	for user, i in page_users {
		rows[i] = []string{
			fmt.tprintf("%d", user.id),
			user.name,
			user.email,
			user.role,
		}
	}

	comp.draw_table(buf, {pos.x, pos.y + 1}, columns, rows, .BrightGreen, .BrightCyan)

	// Draw pagination below table
	table_height := len(page_users) + 4 // rows + borders
	total_pages := comp.calculate_pages(total_items, items_per_page)
	comp.draw_pagination_with_info(
		buf,
		{pos.x, pos.y + table_height},
		current_page,
		total_pages,
		items_per_page,
		total_items,
		.Numbers,
	)
}

// Sample user data structure
User :: struct {
	id:    int,
	name:  string,
	email: string,
	role:  string,
}

// Input handler
input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_key().?; ok {
		#partial switch event.key {
		case .Left:
			return PrevDemo{}
		case .Right:
			return NextDemo{}
		case .Char:
			switch event.char {
			case 'q', 'Q', 3: // q, Q, or Ctrl+C
				return Quit{}
			case 'h', 'H':
				return ToggleHelp{}
			case 'n', 'N':
				return NextPage{}
			case 'p', 'P':
				return PrevPage{}
			case 'f', 'F':
				return FirstPage{}
			case 'l', 'L':
				return LastPage{}
			case '1':
				// This is a simplified implementation
				// You could add direct demo jumping here
				return nil
			}
		}
	}
	return nil
}

main :: proc() {
	// Debug-time memory tracking
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

	// Create and run program
	program := munin.make_program(init, update, view)
	munin.run(&program, input_handler, target_fps = 30)
}
