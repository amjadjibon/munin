package main

import "../../munin/components"
import munin "../../munin"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"

// ============================================================
// MODEL
// ============================================================

Model :: struct {
	roots:         []^components.Tree_Node,
	selected_path: [dynamic]int,
	current_dir:   string,
	show_hidden:   bool,
	show_size:     bool,
	error_msg:     string,
}

// File info for storing in node data
File_Info :: struct {
	path:      string,
	size:      i64,
	is_dir:    bool,
	is_hidden: bool,
}

init :: proc() -> Model {
	allocator := context.allocator

	// Start with current directory
	current_dir := os.get_current_directory(allocator)

	// Build tree from current directory
	show_hidden := false
	roots := build_directory_tree(current_dir, show_hidden, allocator)

	selected_path := make([dynamic]int, allocator)
	if len(roots) > 0 {
		append(&selected_path, 0)
	}

	return Model {
		roots = roots,
		selected_path = selected_path,
		current_dir = current_dir,
		show_hidden = show_hidden,
		show_size = true,
		error_msg = "",
	}
}

// Build tree from directory
build_directory_tree :: proc(
	dir_path: string,
	show_hidden: bool,
	allocator := context.allocator,
) -> []^components.Tree_Node {
	roots := make([dynamic]^components.Tree_Node, allocator)

	// Read directory
	handle, err := os.open(dir_path)
	if err != 0 {
		// Return empty if can't open
		return roots[:]
	}
	defer os.close(handle)

	file_infos, read_err := os.read_dir(handle, -1, allocator)
	if read_err != 0 {
		return roots[:]
	}
	defer delete(file_infos)

	// Sort: directories first, then alphabetically
	slice.sort_by(file_infos[:], proc(a, b: os.File_Info) -> bool {
		if a.is_dir != b.is_dir {
			return a.is_dir
		}
		return a.name < b.name
	})

	// Create nodes for each entry
	for info in file_infos {
		// Skip hidden files if not showing them
		if !show_hidden && len(info.name) > 0 && info.name[0] == '.' {
			continue
		}

		node := create_node_from_file_info(info, dir_path, allocator)
		if node != nil {
			append(&roots, node)
		}
	}

	return roots[:]
}

// Create tree node from file info
create_node_from_file_info :: proc(
	info: os.File_Info,
	parent_path: string,
	allocator := context.allocator,
) -> ^components.Tree_Node {
	full_path := filepath.join({parent_path, info.name}, allocator)

	// Create file info data
	file_data := new(File_Info, allocator)
	file_data.path = full_path
	file_data.size = info.size
	file_data.is_dir = info.is_dir
	file_data.is_hidden = len(info.name) > 0 && info.name[0] == '.'

	// Determine node type and label
	label := info.name
	node_type := components.Tree_Node_Type.File
	color: munin.Color

	if info.is_dir {
		node_type = .Folder
		// Beautiful teal/cyan for directories
		color = munin.RGB{100, 200, 255} // #64C8FF
	} else {
		// Color based on extension with beautiful hex colors
		ext := filepath.ext(info.name)
		switch ext {
		case ".odin":
			color = munin.RGB{138, 180, 248} // #8AB4F8 - Soft blue
		case ".md", ".txt", ".doc", ".docx":
			color = munin.RGB{255, 215, 100} // #FFD764 - Golden yellow
		case ".json", ".toml", ".yaml", ".yml", ".xml":
			color = munin.RGB{152, 224, 152} // #98E098 - Soft green
		case ".sh", ".bash", ".zsh", ".fish":
			color = munin.RGB{255, 138, 138} // #FF8A8A - Soft red
		case ".c", ".cpp", ".h", ".hpp", ".cc":
			color = munin.RGB{134, 142, 255} // #868EFF - Purple
		case ".py", ".pyc":
			color = munin.RGB{100, 180, 255} // #64B4FF - Python blue
		case ".js", ".ts", ".jsx", ".tsx":
			color = munin.RGB{240, 219, 79} // #F0DB4F - JavaScript yellow
		case ".go":
			color = munin.RGB{0, 173, 216} // #00ADD8 - Go cyan
		case ".rs":
			color = munin.RGB{206, 145, 120} // #CE9178 - Rust orange
		case ".html", ".htm", ".css", ".scss":
			color = munin.RGB{255, 125, 125} // #FF7D7D - HTML red
		case ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".svg", ".ico":
			color = munin.RGB{255, 140, 255} // #FF8CFF - Magenta
		case ".mp3", ".wav", ".flac", ".ogg", ".m4a":
			color = munin.RGB{180, 142, 255} // #B48EFF - Purple
		case ".mp4", ".avi", ".mkv", ".mov", ".webm":
			color = munin.RGB{255, 165, 100} // #FFA564 - Orange
		case ".zip", ".tar", ".gz", ".bz2", ".7z", ".rar":
			color = munin.RGB{200, 100, 255} // #C864FF - Purple
		case ".pdf":
			color = munin.RGB{255, 100, 100} // #FF6464 - Red
		case ".exe", ".dll", ".so", ".dylib":
			color = munin.RGB{255, 100, 150} // #FF6496 - Pink
		case:
			// Hidden files in dim gray
			if file_data.is_hidden {
				color = munin.RGB{120, 120, 130} // #787882 - Dim gray
			} else {
				color = munin.RGB{200, 200, 210} // #C8C8D2 - Light gray
			}
		}
	}

	node := components.make_tree_node(
		label,
		node_type,
		expanded = false,
		color = color,
		allocator = allocator,
	)
	node.data = file_data

	return node
}

// Load children for a directory node (lazy loading)
load_directory_children :: proc(
	node: ^components.Tree_Node,
	show_hidden: bool,
	allocator := context.allocator,
) {
	if node == nil || node.type != .Folder {
		return
	}

	// Already loaded?
	if len(node.children) > 0 {
		return
	}

	file_info := cast(^File_Info)node.data
	if file_info == nil {
		return
	}

	// Read directory
	handle, err := os.open(file_info.path)
	if err != 0 {
		return
	}
	defer os.close(handle)

	file_infos, read_err := os.read_dir(handle, -1, allocator)
	if read_err != 0 {
		return
	}
	defer delete(file_infos)

	// Sort: directories first, then alphabetically
	slice.sort_by(file_infos[:], proc(a, b: os.File_Info) -> bool {
		if a.is_dir != b.is_dir {
			return a.is_dir
		}
		return a.name < b.name
	})

	// Create children
	children := make([dynamic]^components.Tree_Node, allocator)
	for info in file_infos {
		// Skip hidden files if not showing them
		if !show_hidden && len(info.name) > 0 && info.name[0] == '.' {
			continue
		}

		child := create_node_from_file_info(info, file_info.path, allocator)
		if child != nil {
			append(&children, child)
		}
	}

	node.children = children[:]
}

// Format file size for display
format_size :: proc(size: i64) -> string {
	if size < 1024 {
		return fmt.tprintf("%dB", size)
	} else if size < 1024 * 1024 {
		return fmt.tprintf("%.1fK", f64(size) / 1024.0)
	} else if size < 1024 * 1024 * 1024 {
		return fmt.tprintf("%.1fM", f64(size) / (1024.0 * 1024.0))
	} else {
		return fmt.tprintf("%.1fG", f64(size) / (1024.0 * 1024.0 * 1024.0))
	}
}

// Validate and fix path if necessary
ensure_valid_path :: proc(
	roots: []^components.Tree_Node,
	path: [dynamic]int,
	allocator := context.allocator,
) -> [dynamic]int {
	// Empty roots = empty path
	if len(roots) == 0 {
		valid_path := make([dynamic]int, allocator)
		return valid_path
	}

	// Check if current path is valid
	if components.find_node_at_path(roots, path[:]) != nil {
		// Path is valid, return a copy
		valid_path := make([dynamic]int, allocator)
		for p in path {
			append(&valid_path, p)
		}
		return valid_path
	}

	// Path is invalid, reset to first item
	valid_path := make([dynamic]int, allocator)
	append(&valid_path, 0)
	return valid_path
}

// ============================================================
// MESSAGES
// ============================================================

Move_Up :: struct {}
Move_Down :: struct {}
Toggle_Expand :: struct {}
Toggle_Hidden :: struct {}
Toggle_Size :: struct {}
Go_Home :: struct {}
Refresh :: struct {}
Quit :: struct {}

Msg :: union {
	Move_Up,
	Move_Down,
	Toggle_Expand,
	Toggle_Hidden,
	Toggle_Size,
	Go_Home,
	Refresh,
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
		// Ensure path is valid first
		valid_path := ensure_valid_path(new_model.roots, new_model.selected_path)
		delete(new_model.selected_path)
		new_model.selected_path = valid_path

		// Navigate up
		new_path, _ := components.navigate_up(
			new_model.roots,
			new_model.selected_path[:],
		)
		delete(new_model.selected_path)
		new_model.selected_path = new_path

	case Move_Down:
		// Ensure path is valid first
		valid_path := ensure_valid_path(new_model.roots, new_model.selected_path)
		delete(new_model.selected_path)
		new_model.selected_path = valid_path

		// Navigate down
		new_path, _ := components.navigate_down(
			new_model.roots,
			new_model.selected_path[:],
		)
		delete(new_model.selected_path)
		new_model.selected_path = new_path

	case Toggle_Expand:
		// Ensure path is valid
		valid_path := ensure_valid_path(new_model.roots, new_model.selected_path)
		delete(new_model.selected_path)
		new_model.selected_path = valid_path

		node := components.find_node_at_path(new_model.roots, new_model.selected_path[:])
		if node != nil && node.type == .Folder {
			if !node.expanded {
				// Load children if not already loaded
				load_directory_children(node, new_model.show_hidden)
			}
			components.toggle_node(node)
		}

	case Toggle_Hidden:
		new_model.show_hidden = !new_model.show_hidden
		// Rebuild entire tree with new filter
		new_model.roots = build_directory_tree(new_model.current_dir, new_model.show_hidden)

		// Reset to valid path
		delete(new_model.selected_path)
		new_model.selected_path = make([dynamic]int)
		if len(new_model.roots) > 0 {
			append(&new_model.selected_path, 0)
		}

	case Toggle_Size:
		new_model.show_size = !new_model.show_size

	case Go_Home:
		// Go to home directory
		home := os.get_env("HOME", context.temp_allocator)
		if len(home) > 0 {
			new_model.current_dir = strings.clone(home)
			new_model.roots = build_directory_tree(new_model.current_dir, new_model.show_hidden)

			// Reset to valid path
			delete(new_model.selected_path)
			new_model.selected_path = make([dynamic]int)
			if len(new_model.roots) > 0 {
				append(&new_model.selected_path, 0)
			}
		}

	case Refresh:
		// Rebuild tree from current directory
		new_model.roots = build_directory_tree(new_model.current_dir, new_model.show_hidden)

		// Reset to valid path
		delete(new_model.selected_path)
		new_model.selected_path = make([dynamic]int)
		if len(new_model.roots) > 0 {
			append(&new_model.selected_path, 0)
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

	// Title with beautiful gradient blue
	title := fmt.tprintf("File System Tree - %s", model.current_dir)
	munin.draw_title(buf, {2, 1}, width - 4, title, munin.RGB{100, 200, 255}, bold = true)

	// Error message if any
	if len(model.error_msg) > 0 {
		munin.print_at(buf, {2, 3}, model.error_msg, munin.RGB{255, 100, 100})
	}

	// Draw tree (starts at line 3 or 4 if error)
	tree_start_y := len(model.error_msg) > 0 ? 4 : 3
	config := components.default_tree_config()
	config.style = .Lines
	config.folder_open_icon = "📂"
	config.folder_close_icon = "📁"
	config.file_icon = "📄"
	config.line_color = munin.RGB{100, 100, 120} // Dim blue-gray for tree lines
	config.selected_color = munin.RGB{138, 255, 138} // Bright green for selection

	// Ensure we have a valid selection path for drawing
	display_path := model.selected_path[:]
	if len(model.roots) > 0 && components.find_node_at_path(model.roots, display_path) == nil {
		// Path is invalid, use first item
		display_path = []int{0}
	}

	// Custom rendering with file sizes
	if model.show_size {
		draw_tree_with_sizes(buf, {2, tree_start_y}, model.roots, display_path, config)
	} else {
		components.draw_tree(buf, {2, tree_start_y}, model.roots, display_path, config)
	}

	// Bottom status area
	status_y := height - 3
	info_y := height - 2
	nav_y := height - 1

	// Status line (file info)
	current_node := components.find_node_at_path(model.roots, model.selected_path[:])
	if current_node != nil {
		file_info := cast(^File_Info)current_node.data
		if file_info != nil {
			status := fmt.tprintf(
				"Selected: %s | Size: %s",
				file_info.path,
				format_size(file_info.size),
			)
			max_len := width - 4
			if len(status) > max_len {
				status = fmt.tprintf("...%s", status[len(status) - max_len + 3:])
			}
			munin.print_at(buf, {2, status_y}, status, munin.RGB{255, 215, 100}) // Golden
		}
	}

	// Info line (toggles)
	toggles := fmt.tprintf(
		"Hidden: %s | Size: %s",
		model.show_hidden ? "ON" : "OFF",
		model.show_size ? "ON" : "OFF",
	)
	toggle_color := munin.RGB{150, 150, 160} // Soft gray
	munin.print_at(buf, {2, info_y}, toggles, toggle_color)

	// Navigation line (instructions)
	instructions :=
		"↑/↓: Navigate  Space/→: Expand  ←: Collapse  .: Hidden  H: Home  R: Refresh  S: Size  Q: Quit"
	munin.print_at(buf, {2, nav_y}, instructions, munin.RGB{100, 200, 255}) // Bright blue
}

// Custom tree drawing with file sizes
draw_tree_with_sizes :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	roots: []^components.Tree_Node,
	selected_path: []int,
	config: components.Tree_Config,
) {
	current_y := pos.y
	for root, i in roots {
		lines := draw_node_with_size(
			buf,
			{pos.x, current_y},
			root,
			0,
			i == len(roots) - 1,
			"",
			selected_path,
			0,
			i,
			config,
		)
		current_y += lines
	}
}

// Draw single node with size
draw_node_with_size :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	node: ^components.Tree_Node,
	depth: int,
	is_last: bool,
	prefix: string,
	selected_path: []int,
	path_index: int,
	current_index: int,
	config: components.Tree_Config,
) -> int {
	if node == nil {
		return 0
	}

	lines_drawn := 0
	current_y := pos.y

	// Check if selected
	is_selected := false
	if len(selected_path) > path_index {
		is_selected = selected_path[path_index] == current_index
		if path_index < len(selected_path) - 1 {
			is_selected = false
		}
	}

	// Draw line
	munin.move_cursor(buf, {pos.x, current_y})

	// Prefix
	if len(prefix) > 0 {
		munin.set_color(buf, config.line_color)
		strings.write_string(buf, prefix)
		munin.reset_style(buf)
	}

	// Connector
	connector := ""
	next_prefix := prefix
	if depth > 0 {
		connector = is_last ? "└── " : "├── "
		next_prefix = strings.concatenate(
			{prefix, is_last ? "    " : "│   "},
			context.temp_allocator,
		)
	}

	if len(connector) > 0 {
		munin.set_color(buf, config.line_color)
		strings.write_string(buf, connector)
		munin.reset_style(buf)
	}

	// Icon
	icon := node.icon
	if config.show_icons && len(icon) == 0 {
		icon = node.expanded ? config.folder_open_icon : config.folder_close_icon
		if node.type == .File {
			icon = config.file_icon
		}
	}

	if len(icon) > 0 {
		strings.write_string(buf, icon)
		strings.write_string(buf, " ")
	}

	// Label
	label_color := node.color
	if is_selected {
		munin.set_bold(buf)
		label_color = config.selected_color
	}

	munin.set_color(buf, label_color)
	strings.write_string(buf, node.label)

	// Size
	file_info := cast(^File_Info)node.data
	if file_info != nil && !file_info.is_dir {
		size_str := fmt.tprintf(" (%s)", format_size(file_info.size))
		munin.set_color(buf, munin.RGB{120, 120, 130}) // Dim gray for sizes
		strings.write_string(buf, size_str)
	}

	munin.reset_style(buf)

	lines_drawn += 1
	current_y += 1

	// Children
	if node.expanded && len(node.children) > 0 {
		next_path_index := path_index
		if is_selected && path_index < len(selected_path) - 1 {
			next_path_index = path_index + 1
		}

		for child, i in node.children {
			child_lines := draw_node_with_size(
				buf,
				{pos.x, current_y},
				child,
				depth + 1,
				i == len(node.children) - 1,
				next_prefix,
				selected_path,
				next_path_index,
				i,
				config,
			)
			lines_drawn += child_lines
			current_y += child_lines
		}
	}

	return lines_drawn
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
			case 'h', 'H':
				return Go_Home{}
			case 'r', 'R':
				return Refresh{}
			case 's', 'S':
				return Toggle_Size{}
			case '.':
				return Toggle_Hidden{}
			}
		} else {
			#partial switch event.key {
			case .Up:
				return Move_Up{}
			case .Down:
				return Move_Down{}
			case .Right:
				return Toggle_Expand{}
			}
		}
	}
	return nil
}

// ============================================================
// MAIN
// ============================================================

main :: proc() {
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
