package main

import "../../components"
import munin "../../munin"
import "core:fmt"
import "core:mem"
import "core:strings"

// ============================================================
// MODEL
// ============================================================

Model :: struct {
	roots:         []^components.Tree_Node,
	selected_path: [dynamic]int,
	show_styled:   bool,
}

init :: proc() -> Model {
	// Create a sample file tree
	allocator := context.allocator

	// Build a project structure
	src_files := make([]^components.Tree_Node, 3, allocator)
	src_files[0] = components.make_tree_node("main.odin", .File, allocator = allocator)
	src_files[1] = components.make_tree_node("utils.odin", .File, allocator = allocator)
	src_files[2] = components.make_tree_node("types.odin", .File, allocator = allocator)

	components_files := make([]^components.Tree_Node, 2, allocator)
	components_files[0] = components.make_tree_node("button.odin", .File, allocator = allocator)
	components_files[1] = components.make_tree_node("input.odin", .File, allocator = allocator)

	test_files := make([]^components.Tree_Node, 1, allocator)
	test_files[0] = components.make_tree_node("main_test.odin", .File, allocator = allocator)

	// Create folder nodes
	src_folder := components.make_tree_node(
		"src",
		.Folder,
		expanded = true,
		children = src_files,
		allocator = allocator,
	)

	components_folder := components.make_tree_node(
		"components",
		.Folder,
		expanded = false,
		children = components_files,
		allocator = allocator,
	)

	tests_folder := components.make_tree_node(
		"tests",
		.Folder,
		expanded = false,
		children = test_files,
		allocator = allocator,
	)

	docs_folder := components.make_tree_node(
		"docs",
		.Folder,
		expanded = false,
		allocator = allocator,
	)

	// Root level files
	readme := components.make_tree_node("README.md", .File, allocator = allocator)
	license := components.make_tree_node("LICENSE", .File, allocator = allocator)

	// Create root level structure
	roots := make([]^components.Tree_Node, 6, allocator)
	roots[0] = src_folder
	roots[1] = components_folder
	roots[2] = tests_folder
	roots[3] = docs_folder
	roots[4] = readme
	roots[5] = license

	selected_path := make([dynamic]int, allocator)
	append(&selected_path, 0) // Select first item

	return Model{roots = roots, selected_path = selected_path, show_styled = false}
}

// ============================================================
// MESSAGES
// ============================================================

Move_Up :: struct {}
Move_Down :: struct {}
Toggle_Expand :: struct {}
Toggle_Style :: struct {}
Expand_All :: struct {}
Collapse_All :: struct {}
Quit :: struct {}

Msg :: union {
	Move_Up,
	Move_Down,
	Toggle_Expand,
	Toggle_Style,
	Expand_All,
	Collapse_All,
	Quit,
}

// ============================================================
// UPDATE
// ============================================================

update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case Move_Up:
		// Navigate to previous visible node
		if new_path, ok := components.navigate_up(
			new_model.roots,
			new_model.selected_path[:],
		); ok {
			delete(new_model.selected_path)
			new_model.selected_path = new_path
		}

	case Move_Down:
		// Navigate to next visible node
		if new_path, ok := components.navigate_down(
			new_model.roots,
			new_model.selected_path[:],
		); ok {
			delete(new_model.selected_path)
			new_model.selected_path = new_path
		}

	case Toggle_Expand:
		node := components.find_node_at_path(
			new_model.roots,
			new_model.selected_path[:],
		)
		if node != nil {
			components.toggle_node(node)
		}

	case Toggle_Style:
		new_model.show_styled = !new_model.show_styled

	case Expand_All:
		for root in new_model.roots {
			components.expand_all(root)
		}

	case Collapse_All:
		for root in new_model.roots {
			components.collapse_all(root)
		}

	case Quit:
		should_quit = true
	}

	return new_model, should_quit
}

// ============================================================
// VIEW
// ============================================================

view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)

	width, height, ok := munin.get_window_size()
	if !ok {
		width = 80
		height = 24
	}

	// Title
	title := "Tree Component Demo"
	munin.draw_title(buf, {2, 1}, width - 4, title, .BrightCyan, bold = true)

	// Instructions
	munin.print_at(
		buf,
		{2, 3},
		"↑/↓: Navigate  Space: Expand/Collapse  S: Toggle Style  E: Expand All  C: Collapse All  Q: Quit",
		munin.Basic_Color.BrightBlack,
	)

	// Draw tree
	if model.show_styled {
		// Use styled rendering
		style := munin.new_style()
		style = munin.style_border(style, munin.Border_Rounded)
		style = munin.style_border_foreground(style, .BrightMagenta)
		style = munin.style_padding(style, 1, 2, 1, 2)
		style = munin.style_margin(style, 1, 0, 0, 2)

		config := components.default_tree_config()
		config.style = .Lines

		rendered := components.render_tree_styled(
			model.roots,
			model.selected_path[:],
			config,
			style,
		)
		defer delete(rendered)

		munin.print_at(buf, {0, 5}, rendered, .Reset)

		munin.print_at(buf, {2, height - 2}, "Styled Mode: ON", .BrightGreen)
	} else {
		// Draw regular tree
		config := components.default_tree_config()
		config.style = .Lines

		components.draw_tree(buf, {4, 5}, model.roots, model.selected_path[:], config)

		munin.print_at(buf, {2, height - 2}, "Styled Mode: OFF", munin.Basic_Color.BrightBlack)
	}

	// Status
	current_node := components.find_node_at_path(model.roots, model.selected_path[:])
	if current_node != nil {
		status := fmt.tprintf("Selected: %s", current_node.label)
		munin.print_at(buf, {width - len(status) - 2, height - 2}, status, .BrightYellow)
	}
}

// ============================================================
// INPUT
// ============================================================

input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_key().?; ok {
		if event.key == .Char {
			switch event.char {
			case 'q', 'Q':
				return Quit{}
			case ' ':
				return Toggle_Expand{}
			case 's', 'S':
				return Toggle_Style{}
			case 'e', 'E':
				return Expand_All{}
			case 'c', 'C':
				return Collapse_All{}
			}
		} else {
			#partial switch event.key {
			case .Up:
				return Move_Up{}
			case .Down:
				return Move_Down{}
			}
		}
	}
	return nil
}

// ============================================================
// MAIN
// ============================================================

main :: proc() {
	// Set up memory tracking in debug mode
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed ===\n", len(track.allocation_map))
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
