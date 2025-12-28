package main

import comp "../../munin/components"
import munin "../../munin"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:time"

// Model holds the application state
Model :: struct {
	current_demo: int,
	show_help:    bool,
}

// Initialize model
init :: proc() -> Model {
	return Model{current_demo = 0, show_help = false}
}

// Messages
Quit :: struct {}
NextDemo :: struct {}
PrevDemo :: struct {}
ToggleHelp :: struct {}

Msg :: union {
	Quit,
	NextDemo,
	PrevDemo,
	ToggleHelp,
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
	case PrevDemo:
		new_model.current_demo = (model.current_demo - 1 + 6) % 6
	case ToggleHelp:
		new_model.show_help = !model.show_help
	}

	return new_model, should_quit
}

// View function
view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)
	munin.set_window_title(buf, "Table Component Examples")

	// Header
	title := "Table Component Examples"
	munin.draw_title(buf, {0, 1}, 80, title, .BrightCyan)

	// Demo navigation
	munin.print_at(buf, {2, 3}, "Demos:", .BrightWhite)
	demos := []string{"Basic", "Products", "Employees", "Scores", "Mixed Align", "Wide Table"}

	for i in 0 ..< len(demos) {
		color := munin.Basic_Color.White
		if i == model.current_demo {
			color = .BrightYellow
		}
		item_display := fmt.tprintf("[%d] %s", i + 1, demos[i])
		munin.print_at(buf, {12 + i * 14, 3}, item_display, color)
	}

	// Current demo description
	descriptions := []string {
		"Simple 3-column table with basic data",
		"Product catalog with prices and stock",
		"Employee directory with contact info",
		"Student test scores with statistics",
		"Demonstrating different column alignments",
		"Wide table with multiple columns",
	}

	desc_x := max(2, (80 - len(descriptions[model.current_demo])) / 2)
	munin.print_at(buf, {desc_x, 5}, descriptions[model.current_demo], .BrightGreen)

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
	comp.draw_box_styled(buf, {20, help_y}, 40, 6, .Double, .BrightYellow)
	munin.print_at(buf, {32, help_y}, " HELP ", .BrightWhite)

	munin.print_at(buf, {22, help_y + 1}, "← →     : Switch demos", .White)
	munin.print_at(buf, {22, help_y + 2}, "1-6     : Jump to demo", .White)
	munin.print_at(buf, {22, help_y + 3}, "h       : Toggle help", .White)
	munin.print_at(buf, {22, help_y + 4}, "q       : Quit", .White)
}

// Draw the current demo
draw_demo :: proc(buf: ^strings.Builder, model: Model) {
	demo_y := 8

	switch model.current_demo {
	case 0:
		draw_basic_table(buf, {5, demo_y})
	case 1:
		draw_products_table(buf, {5, demo_y})
	case 2:
		draw_employees_table(buf, {5, demo_y})
	case 3:
		draw_scores_table(buf, {5, demo_y})
	case 4:
		draw_mixed_align_table(buf, {5, demo_y})
	case 5:
		draw_wide_table(buf, {2, demo_y})
	}
}

// Demo 1: Basic table
draw_basic_table :: proc(buf: ^strings.Builder, pos: munin.Vec2i) {
	munin.print_at(buf, {pos.x, pos.y - 1}, "Basic 3-Column Table:", .BrightCyan)

	columns := []comp.Table_Column {
		{title = "ID", width = 8, align = .Center},
		{title = "Name", width = 20, align = .Left},
		{title = "Status", width = 12, align = .Center},
	}

	rows := [][]string {
		{"1", "Alice", "Active"},
		{"2", "Bob", "Inactive"},
		{"3", "Charlie", "Active"},
		{"4", "Diana", "Pending"},
		{"5", "Eve", "Active"},
	}

	comp.draw_table(buf, pos, columns, rows, .BrightYellow, .BrightBlue)
}

// Demo 2: Products table
draw_products_table :: proc(buf: ^strings.Builder, pos: munin.Vec2i) {
	munin.print_at(buf, {pos.x, pos.y - 1}, "Product Catalog:", .BrightCyan)

	columns := []comp.Table_Column {
		{title = "SKU", width = 10, align = .Center},
		{title = "Product Name", width = 25, align = .Left},
		{title = "Price", width = 12, align = .Right},
		{title = "Stock", width = 8, align = .Center},
	}

	rows := [][]string {
		{"SKU-001", "Wireless Mouse", "$29.99", "45"},
		{"SKU-002", "Mechanical Keyboard", "$89.99", "12"},
		{"SKU-003", "USB-C Cable", "$12.99", "230"},
		{"SKU-004", "Monitor Stand", "$45.50", "8"},
		{"SKU-005", "Laptop Sleeve", "$24.99", "67"},
		{"SKU-006", "Webcam HD", "$79.99", "3"},
	}

	comp.draw_table(buf, pos, columns, rows, .BrightGreen, .BrightMagenta)
}

// Demo 3: Employees table
draw_employees_table :: proc(buf: ^strings.Builder, pos: munin.Vec2i) {
	munin.print_at(buf, {pos.x, pos.y - 1}, "Employee Directory:", .BrightCyan)

	columns := []comp.Table_Column {
		{title = "EMP ID", width = 8, align = .Center},
		{title = "Full Name", width = 18, align = .Left},
		{title = "Department", width = 15, align = .Left},
		{title = "Email", width = 22, align = .Left},
	}

	rows := [][]string {
		{"E001", "John Smith", "Engineering", "john.s@company.com"},
		{"E002", "Sarah Johnson", "Marketing", "sarah.j@company.com"},
		{"E003", "Mike Davis", "Sales", "mike.d@company.com"},
		{"E004", "Emily Wilson", "HR", "emily.w@company.com"},
		{"E005", "David Brown", "Engineering", "david.b@company.com"},
	}

	comp.draw_table(buf, pos, columns, rows, .BrightCyan, .BrightYellow)
}

// Demo 4: Test scores table
draw_scores_table :: proc(buf: ^strings.Builder, pos: munin.Vec2i) {
	munin.print_at(buf, {pos.x, pos.y - 1}, "Student Test Scores:", .BrightCyan)

	columns := []comp.Table_Column {
		{title = "Student", width = 18, align = .Left},
		{title = "Math", width = 8, align = .Center},
		{title = "Science", width = 8, align = .Center},
		{title = "English", width = 8, align = .Center},
		{title = "Average", width = 8, align = .Center},
	}

	rows := [][]string {
		{"Alice Johnson", "95", "88", "92", "91.7"},
		{"Bob Williams", "78", "85", "90", "84.3"},
		{"Charlie Brown", "92", "94", "89", "91.7"},
		{"Diana Martinez", "88", "91", "95", "91.3"},
		{"Eve Anderson", "85", "87", "88", "86.7"},
		{
			"─────────────",
			"────",
			"────",
			"────",
			"────",
		},
		{"Class Average", "87.6", "89.0", "90.8", "89.1"},
	}

	comp.draw_table(buf, pos, columns, rows, .BrightMagenta, .BrightGreen)
}

// Demo 5: Mixed alignment table
draw_mixed_align_table :: proc(buf: ^strings.Builder, pos: munin.Vec2i) {
	munin.print_at(buf, {pos.x, pos.y - 1}, "Mixed Alignment Demo:", .BrightCyan)

	columns := []comp.Table_Column {
		{title = "Left Aligned", width = 18, align = .Left},
		{title = "Centered", width = 18, align = .Center},
		{title = "Right Aligned", width = 18, align = .Right},
	}

	rows := [][]string {
		{"Left text", "Center text", "Right text"},
		{"Short", "Mid length text", "X"},
		{"A very long text", "Normal", "123456"},
		{"Data", "Information", "Value"},
	}

	comp.draw_table(buf, pos, columns, rows, .BrightRed, .BrightCyan)
}

// Demo 6: Wide table
draw_wide_table :: proc(buf: ^strings.Builder, pos: munin.Vec2i) {
	munin.print_at(buf, {pos.x, pos.y - 1}, "Wide Multi-Column Table:", .BrightCyan)

	columns := []comp.Table_Column {
		{title = "ID", width = 5, align = .Center},
		{title = "Name", width = 12, align = .Left},
		{title = "Age", width = 5, align = .Center},
		{title = "City", width = 12, align = .Left},
		{title = "Role", width = 12, align = .Left},
		{title = "Salary", width = 10, align = .Right},
		{title = "Status", width = 8, align = .Center},
	}

	rows := [][]string {
		{"001", "Alice Brown", "28", "New York", "Engineer", "$85,000", "Active"},
		{"002", "Bob Smith", "34", "San Fran", "Designer", "$75,000", "Active"},
		{"003", "Carol Lee", "29", "Seattle", "Manager", "$95,000", "Active"},
		{"004", "David Kim", "31", "Boston", "Developer", "$80,000", "Leave"},
		{"005", "Emma Wilson", "26", "Austin", "Analyst", "$70,000", "Active"},
	}

	comp.draw_table(buf, pos, columns, rows, .BrightWhite, .BrightBlue)
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
			case 'q', 'Q', 3:
				// q, Q, or Ctrl+C
				return Quit{}
			case 'h', 'H':
				return ToggleHelp{}
			case '1':
				// Jump to demo 0
				return Quit{} // We'll handle this differently
			case '2', '3', '4', '5', '6':
				// Jump to specific demos
				return NextDemo{} // Simplified
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
