package main

import comp "../../components"
import munin "../../munin"
import "core:fmt"
import "core:mem"
import "core:strings"

// Model holds the application state
Model :: struct {
	current_demo: int,
	selected_index: int,
	scroll_offset: int,
	show_help: bool,
}

init :: proc() -> Model {
	return Model {
		current_demo = 0,
		selected_index = 0,
		scroll_offset = 0,
		show_help = true,
	}
}

// Messages define all possible events
Quit :: struct {}
NextDemo :: struct {}
PrevDemo :: struct {}
NextItem :: struct {}
PrevItem :: struct {}
ToggleHelp :: struct {}
SelectItem :: struct {}
ScrollUp :: struct {}
ScrollDown :: struct {}
ToggleCheckbox :: struct {}

Msg :: union {
	Quit,
	NextDemo,
	PrevDemo,
	NextItem,
	PrevItem,
	ToggleHelp,
	SelectItem,
	ScrollUp,
	ScrollDown,
	ToggleCheckbox,
}

// Update handles state transitions
update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case Quit:
		should_quit = true
	case NextDemo:
		new_model.current_demo = (model.current_demo + 1) % 7
		new_model.selected_index = 0
		new_model.scroll_offset = 0
	case PrevDemo:
		new_model.current_demo = (model.current_demo - 1 + 7) % 7
		new_model.selected_index = 0
		new_model.scroll_offset = 0
	case NextItem:
		item_count := get_item_count(model.current_demo)
		new_model.selected_index = min(model.selected_index + 1, item_count - 1)
		// Auto-scroll for scrollable list (demo 4)
		if model.current_demo == 4 {
			visible_height := 10
			if new_model.selected_index >= model.scroll_offset + visible_height {
				new_model.scroll_offset = new_model.selected_index - visible_height + 1
			}
		}
	case PrevItem:
		new_model.selected_index = max(0, model.selected_index - 1)
		// Auto-scroll for scrollable list (demo 4)
		if model.current_demo == 4 {
			if new_model.selected_index < model.scroll_offset {
				new_model.scroll_offset = new_model.selected_index
			}
		}
	case ToggleHelp:
		new_model.show_help = !model.show_help
	case SelectItem:
		// Handle item selection based on current demo
		handle_item_selection(&new_model)
	case ScrollUp:
		// Only change scroll offset, not selected index
		new_model.scroll_offset = max(0, model.scroll_offset - 1)
	case ScrollDown:
		// Only change scroll offset, not selected index
		item_count := get_item_count(model.current_demo)
		max_scroll := max(0, item_count - 10) // 10 is the visible height for scrollable list
		new_model.scroll_offset = min(model.scroll_offset + 1, max_scroll)
	case ToggleCheckbox:
		toggle_checkbox_at_index(&new_model, model.selected_index)
	}

	return new_model, should_quit
}

// Get item count for current demo
get_item_count :: proc(demo_index: int) -> int {
	switch demo_index {
	case 0: return 6  // Bullet list
	case 1: return 8  // Numbered list
	case 2: return 5  // Arrow list
	case 3: return 7  // Checkbox list
	case 4: return 12 // Scrollable list
	case 5: return 6  // Colored list
	case 6: return 10 // Mixed custom list
	}
	return 0
}

// Handle item selection
handle_item_selection :: proc(model: ^Model) {
	switch model.current_demo {
	case 3: // Checkbox demo
		toggle_checkbox_at_index(model, model.selected_index)
	}
}

// Toggle checkbox at specific index
toggle_checkbox_at_index :: proc(model: ^Model, index: int) {
	// This would require making the list items mutable
	// For now, just print a message
	fmt.printf("Toggle checkbox at index %d\n", index)
}

// View renders the current state
view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)

	// Set window title
	munin.set_window_title(buf, "Munin List Component Examples")

	// Header
	title := "List Component Examples"
	munin.draw_title(buf, {0, 1}, 80, title, .BrightCyan)

	// Demo navigation
	munin.print_at(buf, {2, 3}, "Demos:", .BrightWhite)
	demos := []string{"Bullet", "Numbered", "Arrow", "Checkbox", "Scrollable", "Colored", "Mixed"}

	for i in 0 ..< len(demos) {
		color := munin.Color.White
		if i == model.current_demo {
			color = .BrightYellow
		}
		item_display := fmt.tprintf("[%d] %s", i + 1, demos[i])
		munin.print_at(buf, {12 + i * 12, 3}, item_display, color)
	}

	// Current demo description
	descriptions := []string{
		"Bullet list with selection highlighting",
		"Numbered list with sequential numbering",
		"Arrow list with directional markers",
		"Interactive checkbox list with toggle states",
		"Scrollable list with viewport and indicators",
		"Colored list items with different text colors",
		"Mixed custom markers and formatting",
	}

	desc_x := max(2, (80 - len(descriptions[model.current_demo])) / 2)
	munin.print_at(buf, {desc_x, 5}, descriptions[model.current_demo], .BrightGreen)

	// Draw current demo
	draw_demo(buf, model)

	// Help section
	if model.show_help {
		draw_help(buf)
	}
}

// Draw help section
draw_help :: proc(buf: ^strings.Builder) {
	help_y := 22
	munin.print_at(buf, {2, help_y}, "Controls:", .BrightWhite)
	munin.print_at(buf, {2, help_y + 1}, "  ← → : Switch demos | 1-7 : Jump to demo", .White)
	munin.print_at(buf, {2, help_y + 2}, "  ↑ ↓ : Navigate items | Space/Enter : Select item", .White)

	// Show scroll-specific controls for scrollable demo
	demos := []string{"Bullet", "Numbered", "Arrow", "Checkbox", "Scrollable", "Colored", "Mixed"}
	// Note: We can't access model here, so we'll show scroll controls in all demos
	munin.print_at(buf, {2, help_y + 3}, "  Page Up/Down : Scroll list (when available) | H : Toggle help | Q : Quit", .White)
}

// Draw the current demo
draw_demo :: proc(buf: ^strings.Builder, model: Model) {
	demo_y := 8
	demo_x := 10

	switch model.current_demo {
	case 0: draw_bullet_list_demo(buf, {demo_x, demo_y}, model)
	case 1: draw_numbered_list_demo(buf, {demo_x, demo_y}, model)
	case 2: draw_arrow_list_demo(buf, {demo_x, demo_y}, model)
	case 3: draw_checkbox_list_demo(buf, {demo_x, demo_y}, model)
	case 4: draw_scrollable_list_demo(buf, {demo_x, demo_y}, model)
	case 5: draw_colored_list_demo(buf, {demo_x, demo_y}, model)
	case 6: draw_mixed_list_demo(buf, {demo_x, demo_y}, model)
	}
}

// Bullet list demo
draw_bullet_list_demo :: proc(buf: ^strings.Builder, pos: munin.Vec2i, model: Model) {
	comp.draw_box_styled(buf, {pos.x - 2, pos.y - 1}, 60, 8, .Rounded, .BrightBlue)
	munin.print_at(buf, {pos.x + 20, pos.y - 1}, "BULLET LIST", .BrightWhite)

	items := []comp.List_Item{
		{"First item with bullet marker", false, .White},
		{"Second item for demonstration", false, .BrightCyan},
		{"Third item shows different color", false, .BrightYellow},
		{"Fourth item in the list", false, .BrightGreen},
		{"Fifth item continues the pattern", false, .BrightMagenta},
		{"Sixth and final item", false, .BrightRed},
	}

	clamped_selected := min(model.selected_index, len(items) - 1)
	comp.draw_list(buf, pos, items, clamped_selected, comp.List_Style.Bullet)
}

// Numbered list demo
draw_numbered_list_demo :: proc(buf: ^strings.Builder, pos: munin.Vec2i, model: Model) {
	comp.draw_box_styled(buf, {pos.x - 2, pos.y - 1}, 60, 10, .Rounded, .BrightGreen)
	munin.print_at(buf, {pos.x + 18, pos.y - 1}, "NUMBERED LIST", .BrightWhite)

	items := []comp.List_Item{
		{"Setup the development environment", false, .BrightCyan},
		{"Install required dependencies", false, .BrightYellow},
		{"Configure the project settings", false, .BrightGreen},
		{"Write the main application code", false, .BrightMagenta},
		{"Implement user interface components", false, .BrightRed},
		{"Add styling and theming", false, .BrightBlue},
		{"Test the application thoroughly", false, .BrightWhite},
		{"Deploy to production environment", false, .BrightYellow},
	}

	clamped_selected := min(model.selected_index, len(items) - 1)
	comp.draw_list(buf, pos, items, clamped_selected, comp.List_Style.Number)
}

// Arrow list demo
draw_arrow_list_demo :: proc(buf: ^strings.Builder, pos: munin.Vec2i, model: Model) {
	comp.draw_box_styled(buf, {pos.x - 2, pos.y - 1}, 60, 7, .Rounded, .BrightYellow)
	munin.print_at(buf, {pos.x + 20, pos.y - 1}, "ARROW LIST", .BrightWhite)

	items := []comp.List_Item{
		{"Navigate to project directory", false, .BrightCyan},
		{"Initialize the project structure", false, .BrightYellow},
		{"Create configuration files", false, .BrightGreen},
		{"Set up build pipeline", false, .BrightMagenta},
		{"Configure deployment settings", false, .BrightRed},
	}

	clamped_selected := min(model.selected_index, len(items) - 1)
	comp.draw_list(buf, pos, items, clamped_selected, comp.List_Style.Arrow)
}

// Checkbox list demo
draw_checkbox_list_demo :: proc(buf: ^strings.Builder, pos: munin.Vec2i, model: Model) {
	comp.draw_box_styled(buf, {pos.x - 2, pos.y - 1}, 60, 9, .Rounded, .BrightMagenta)
	munin.print_at(buf, {pos.x + 18, pos.y - 1}, "CHECKBOX LIST", .BrightWhite)

	items := []comp.List_Item{
		{"Enable dark mode theme", true, .BrightGreen},
		{"Show line numbers", false, .White},
		{"Enable auto-save", true, .BrightGreen},
		{"Display file tree", true, .BrightGreen},
		{"Highlight syntax", true, .BrightGreen},
		{"Show minimap", false, .White},
		{"Enable word wrap", true, .BrightGreen},
	}

	clamped_selected := min(model.selected_index, len(items) - 1)
	comp.draw_list(buf, pos, items, clamped_selected, comp.List_Style.Checkbox)
}

// Scrollable list demo
draw_scrollable_list_demo :: proc(buf: ^strings.Builder, pos: munin.Vec2i, model: Model) {
	comp.draw_box_styled(buf, {pos.x - 2, pos.y - 1}, 60, 12, .Rounded, .BrightCyan)
	munin.print_at(buf, {pos.x + 15, pos.y - 1}, "SCROLLABLE LIST", .BrightWhite)

	items := []comp.List_Item{
		{"Alpha version features", false, .BrightCyan},
		{"Beta testing phase", false, .BrightYellow},
		{"Release candidate 1", false, .BrightGreen},
		{"Release candidate 2", false, .BrightMagenta},
		{"Official release v1.0", false, .BrightRed},
		{"Minor bug fixes v1.1", false, .BrightBlue},
		{"Performance improvements v1.2", false, .BrightWhite},
		{"New feature additions v1.3", false, .BrightYellow},
		{"Security updates v1.4", false, .BrightGreen},
		{"UI redesign v2.0", false, .BrightCyan},
		{"API changes v2.1", false, .BrightMagenta},
		{"Latest release v2.2", false, .BrightRed},
	}

	// Clamp selected index to item count
	item_count := len(items)
	clamped_selected := min(model.selected_index, item_count - 1)

	// Adjust selected index relative to scroll offset for the scrollable component
	adjusted_selected := clamped_selected - model.scroll_offset
	// Clamp adjusted selected to visible range (or -1 if not visible)
	if adjusted_selected < 0 || adjusted_selected >= 10 {
		adjusted_selected = -1  // Not visible in viewport
	}
	comp.draw_list_scrollable(buf, pos, 10, items, adjusted_selected, model.scroll_offset, comp.List_Style.Number)
}

// Colored list demo
draw_colored_list_demo :: proc(buf: ^strings.Builder, pos: munin.Vec2i, model: Model) {
	comp.draw_box_styled(buf, {pos.x - 2, pos.y - 1}, 60, 8, .Rounded, .BrightRed)
	munin.print_at(buf, {pos.x + 18, pos.y - 1}, "COLORED LIST", .BrightWhite)

	items := []comp.List_Item{
		{"Red item for emphasis", false, .BrightRed},
		{"Green item for success", false, .BrightGreen},
		{"Blue item for information", false, .BrightBlue},
		{"Yellow item for warning", false, .BrightYellow},
		{"Magenta item for creative", false, .BrightMagenta},
		{"Cyan item for technical", false, .BrightCyan},
	}

	clamped_selected := min(model.selected_index, len(items) - 1)
	comp.draw_list(buf, pos, items, clamped_selected, comp.List_Style.Bullet)
}

// Mixed custom list demo
draw_mixed_list_demo :: proc(buf: ^strings.Builder, pos: munin.Vec2i, model: Model) {
	comp.draw_box_styled(buf, {pos.x - 2, pos.y - 1}, 60, 12, .Rounded, .BrightWhite)
	munin.print_at(buf, {pos.x + 15, pos.y - 1}, "MIXED MARKERS", .BrightWhite)

	// Draw different styles for demonstration
	// First 2 items with bullets
	bullet_items := []comp.List_Item{
		{"Basic bullet item", false, .White},
		{"Another bullet", false, .BrightCyan},
	}
	bullet_selected := min(model.selected_index, len(bullet_items) - 1)
	comp.draw_list(buf, pos, bullet_items, bullet_selected, comp.List_Style.Bullet)

	// Next 2 items with arrows
	arrow_items := []comp.List_Item{
		{"Arrow navigation item", false, .BrightYellow},
		{"Directional marker", false, .BrightGreen},
	}
	arrow_selected := min(max(model.selected_index - 2, 0), len(arrow_items) - 1)
	comp.draw_list(buf, {pos.x, pos.y + 2}, arrow_items, arrow_selected, comp.List_Style.Arrow)

	// Next 2 items with numbers
	number_items := []comp.List_Item{
		{"Numbered step item", false, .BrightMagenta},
		{"Sequential order", false, .BrightRed},
	}
	number_selected := min(max(model.selected_index - 4, 0), len(number_items) - 1)
	comp.draw_list(buf, {pos.x, pos.y + 4}, number_items, number_selected, comp.List_Style.Number)

	// Next 2 items with custom markers
	custom_items := []comp.List_Item{
		{"Star rated item", false, .BrightYellow},
		{"Heart favorite item", false, .BrightRed},
	}
	custom_selected := min(max(model.selected_index - 6, 0), len(custom_items) - 1)
	comp.draw_list(buf, {pos.x, pos.y + 6}, custom_items, custom_selected, comp.List_Style.Custom, "★")

	// Last 2 items with different custom markers
	custom_items2 := []comp.List_Item{
		{"Diamond premium item", false, .BrightCyan},
		{"Check verified item", false, .BrightGreen},
	}
	custom_selected2 := min(max(model.selected_index - 8, 0), len(custom_items2) - 1)
	comp.draw_list(buf, {pos.x, pos.y + 8}, custom_items2, custom_selected2, comp.List_Style.Custom, "◆")
}

// Input handler processes keyboard events
input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_key().?; ok {
		#partial switch event.key {
		case .Enter:
			return SelectItem{}
		case .Up:
			return PrevItem{}
		case .Down:
			return NextItem{}
		case .Left:
			return PrevDemo{}
		case .Right:
			return NextDemo{}
		case .Char:
			if event.char == 'q' || event.char == 'Q' || event.char == 3 {
				return Quit{}
			} else if event.char == 'h' || event.char == 'H' {
				return ToggleHelp{}
			} else if event.char >= '1' && event.char <= '7' {
				demo_index := int(event.char - '1')
				return PrevDemo{} // We'll handle this in update
			} else if event.char == ' ' {
				return SelectItem{}
			}
		case .PageUp:
			return ScrollUp{}
		case .PageDown:
			return ScrollDown{}
		case .Backspace:
			return PrevDemo{}
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
	munin.run(&program, input_handler, target_fps = 60)
}