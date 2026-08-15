package components

import munin ".."
import "core:strings"

// ============================================================
// TREE COMPONENT
// ============================================================

// Tree node type for different kinds of items
Tree_Node_Type :: enum {
	Folder,
	File,
	Custom,
}

// Tree node representing a hierarchical item
Tree_Node :: struct {
	label:    string,
	type:     Tree_Node_Type,
	expanded: bool, // Whether children are visible
	children: []^Tree_Node,
	icon:     string, // Custom icon (optional)
	color:    munin.Color,
	data:     rawptr, // User data
}

// Tree drawing style
Tree_Style :: enum {
	Lines, // ├──, └──, │
	Ascii, // |-, +-, |
	Dots, // ···
	Simple, // No connectors
}

// Tree configuration
Tree_Config :: struct {
	style:             Tree_Style,
	indent:            int,
	show_icons:        bool,
	folder_open_icon:  string,
	folder_close_icon: string,
	file_icon:         string,
	line_color:        munin.Color,
	folder_color:      munin.Color,
	file_color:        munin.Color,
	selected_color:    munin.Color,
}

// Default tree configuration
default_tree_config :: proc() -> Tree_Config {
	return Tree_Config {
		style = .Lines,
		indent = 2,
		show_icons = true,
		folder_open_icon = "📂",
		folder_close_icon = "📁",
		file_icon = "📄",
		line_color = munin.Basic_Color.BrightBlack,
		folder_color = munin.Basic_Color.BrightYellow,
		file_color = munin.Basic_Color.White,
		selected_color = munin.Basic_Color.BrightCyan,
	}
}

// Helper to create a tree node
make_tree_node :: proc(
	label: string,
	type: Tree_Node_Type = .File,
	expanded := false,
	children: []^Tree_Node = nil,
	color: munin.Color = munin.Basic_Color.Reset,
	icon := "",
	allocator := context.allocator,
) -> ^Tree_Node {
	node := new(Tree_Node, allocator)
	node.label = label
	node.type = type
	node.expanded = expanded
	node.children = children
	node.icon = icon
	node.color = color
	return node
}

// How a tree is emitted.
//
// Positioned output moves the cursor to an absolute screen row for each line,
// which is what a full-screen layout wants. Flowed output separates lines with
// newlines and emits no cursor movement at all, so the result can be measured,
// padded, framed by style_render(), or joined next to something else.
@(private)
Tree_Render :: struct {
	positioned:    bool,
	origin:        munin.Vec2i,
	line:          int, // lines emitted so far
	config:        Tree_Config,
	selected_path: []int,
	sanitize:      bool,
}

@(private)
tree_begin_line :: proc(buf: ^strings.Builder, r: ^Tree_Render) {
	if r.positioned {
		munin.move_cursor(buf, {r.origin.x, r.origin.y + r.line})
	} else if r.line > 0 {
		strings.write_byte(buf, '\n')
	}
	r.line += 1
}

// Draw a tree starting from root nodes, positioned at pos.
// Returns the number of lines drawn.
draw_tree :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	roots: []^Tree_Node,
	selected_path: []int = nil, // Path to selected node [root_idx, child_idx, ...]
	config: Tree_Config,
	// Node labels are stripped of escape sequences and control bytes: a tree
	// usually shows filenames or other data the application did not author.
	sanitize: bool = true,
) -> int {
	r := Tree_Render {
		positioned    = true,
		origin        = pos,
		config        = config,
		selected_path = selected_path,
		sanitize      = sanitize,
	}
	write_tree(buf, roots, &r)
	return r.line
}

// Render a tree as flowed text: newline-separated lines, no cursor movement.
//
// Use this when the tree has to compose with anything else - style_render(),
// join_horizontal(), a measured region. draw_tree() writes absolute cursor
// moves, which ignore wherever the surrounding layout meant to put the
// content.
//
// The result is owned by the caller.
render_tree :: proc(
	roots: []^Tree_Node,
	selected_path: []int = nil,
	config: Tree_Config,
	sanitize: bool = true,
	allocator := context.allocator,
) -> string {
	buf := strings.builder_make(allocator)

	r := Tree_Render {
		positioned    = false,
		config        = config,
		selected_path = selected_path,
		sanitize      = sanitize,
	}
	write_tree(buf_ptr(&buf), roots, &r)

	return strings.to_string(buf)
}

@(private)
buf_ptr :: proc(b: ^strings.Builder) -> ^strings.Builder {
	return b
}

@(private)
write_tree :: proc(buf: ^strings.Builder, roots: []^Tree_Node, r: ^Tree_Render) {
	for root, i in roots {
		write_tree_node(buf, root, 0, i == len(roots) - 1, "", 0, i, r)
	}
}

// Internal: write a single tree node and its children recursively
@(private)
write_tree_node :: proc(
	buf: ^strings.Builder,
	node: ^Tree_Node,
	depth: int,
	is_last: bool,
	prefix: string,
	path_index: int,
	current_index: int,
	r: ^Tree_Render,
) {
	if node == nil {
		return
	}

	config := r.config

	// Check if this node is selected
	is_selected := false
	if len(r.selected_path) > path_index {
		is_selected = r.selected_path[path_index] == current_index
		if path_index < len(r.selected_path) - 1 {
			is_selected = false // Not the final node in path
		}
	}

	tree_begin_line(buf, r)

	// Draw prefix (inherited from parent levels)
	if len(prefix) > 0 {
		munin.set_color(buf, config.line_color)
		strings.write_string(buf, prefix)
		munin.reset_style(buf)
	}

	// Draw connector
	connector := ""
	next_prefix := prefix

	switch config.style {
	case .Lines:
		if depth > 0 {
			connector = is_last ? "└── " : "├── "
			next_prefix = strings.concatenate(
				{prefix, is_last ? "    " : "│   "},
				context.temp_allocator,
			)
		}
	case .Ascii:
		if depth > 0 {
			connector = is_last ? "+-- " : "|-- "
			next_prefix = strings.concatenate(
				{prefix, is_last ? "    " : "|   "},
				context.temp_allocator,
			)
		}
	case .Dots:
		if depth > 0 {
			connector = "··· "
			next_prefix = strings.concatenate({prefix, "    "}, context.temp_allocator)
		}
	case .Simple:
		if depth > 0 {
			connector = strings.repeat(" ", config.indent, context.temp_allocator)
			next_prefix = strings.concatenate(
				{prefix, strings.repeat(" ", config.indent, context.temp_allocator)},
				context.temp_allocator,
			)
		}
	}

	if len(connector) > 0 {
		munin.set_color(buf, config.line_color)
		strings.write_string(buf, connector)
		munin.reset_style(buf)
	}

	// Draw icon
	icon := node.icon
	if config.show_icons && len(icon) == 0 {
		switch node.type {
		case .Folder:
			icon = node.expanded ? config.folder_open_icon : config.folder_close_icon
		case .File:
			icon = config.file_icon
		case .Custom:
			icon = ""
		}
	}

	if len(icon) > 0 {
		strings.write_string(buf, icon)
		strings.write_string(buf, " ")
	}

	// Draw label
	label_color := node.color
	if munin.is_color_reset(label_color) {
		switch node.type {
		case .Folder:
			label_color = config.folder_color
		case .File:
			label_color = config.file_color
		case .Custom:
			label_color = munin.Basic_Color.White
		}
	}

	if is_selected {
		munin.set_bold(buf)
		label_color = config.selected_color
	}

	munin.set_color(buf, label_color)
	strings.write_string(buf, display_text(node.label, r.sanitize))
	munin.reset_style(buf)

	// Draw children if expanded
	if node.expanded && len(node.children) > 0 {
		// Check if we should continue down the selected path
		next_path_index := path_index
		if is_selected && path_index < len(r.selected_path) - 1 {
			next_path_index = path_index + 1
		}

		for child, i in node.children {
			write_tree_node(
				buf,
				child,
				depth + 1,
				i == len(node.children) - 1,
				next_prefix,
				next_path_index,
				i,
				r,
			)
		}
	}
}

// Styled tree: render the tree as flowed text and apply a style to it.
//
// This goes through render_tree(), not draw_tree(): a tree drawn with absolute
// cursor moves lands wherever those moves point, not inside the border and
// padding the style just laid out around it.
//
// The result is owned by the caller.
render_tree_styled :: proc(
	roots: []^Tree_Node,
	selected_path: []int = nil,
	config: Tree_Config,
	style: munin.Style,
	sanitize: bool = true,
) -> string {
	content := render_tree(roots, selected_path, config, sanitize, context.temp_allocator)

	// Apply style if provided
	if style.foreground != nil ||
	   style.background != nil ||
	   style.border != nil ||
	   style.padding != {0, 0, 0, 0} ||
	   style.margin != {0, 0, 0, 0} {
		return munin.style_render(style, content)
	}

	// Return plain content
	return strings.clone(content)
}

// Helper to toggle node expansion
toggle_node :: proc(node: ^Tree_Node) {
	if node != nil && node.type == .Folder {
		node.expanded = !node.expanded
	}
}

// Helper to expand all nodes recursively
expand_all :: proc(node: ^Tree_Node) {
	if node == nil {
		return
	}
	if node.type == .Folder {
		node.expanded = true
	}
	for child in node.children {
		expand_all(child)
	}
}

// Helper to collapse all nodes recursively
collapse_all :: proc(node: ^Tree_Node) {
	if node == nil {
		return
	}
	if node.type == .Folder {
		node.expanded = false
	}
	for child in node.children {
		collapse_all(child)
	}
}

// Find node at path (indices from root)
find_node_at_path :: proc(roots: []^Tree_Node, path: []int) -> ^Tree_Node {
	// Negative indices must be rejected as well as out-of-range ones - a
	// caller-supplied path is just data, and roots[-1] is an out-of-bounds
	// read.
	if len(path) == 0 || path[0] < 0 || path[0] >= len(roots) {
		return nil
	}

	current := roots[path[0]]
	for i in 1 ..< len(path) {
		if current == nil || path[i] < 0 || path[i] >= len(current.children) {
			return nil
		}
		current = current.children[path[i]]
	}
	return current
}

// Visible node with its path (for navigation)
Visible_Node :: struct {
	node:  ^Tree_Node,
	path:  [dynamic]int,
	depth: int,
}

// Free a slice returned by get_visible_nodes, including the path owned by
// each entry. Without this the per-entry paths are a loop every caller has to
// remember to write.
destroy_visible_nodes :: proc(visible: [dynamic]Visible_Node) {
	nodes := visible
	for v in nodes {
		delete(v.path)
	}
	delete(nodes)
}

// Get all visible nodes in traversal order (respecting expanded/collapsed
// state). The result and every entry's path are owned by the caller: release
// them with destroy_visible_nodes().
get_visible_nodes :: proc(
	roots: []^Tree_Node,
	allocator := context.allocator,
) -> [dynamic]Visible_Node {
	visible := make([dynamic]Visible_Node, allocator)

	for root, i in roots {
		if root == nil {
			continue
		}

		path := make([dynamic]int, allocator)
		append(&path, i)

		append(&visible, Visible_Node{node = root, path = path, depth = 0})

		if root.expanded && len(root.children) > 0 {
			collect_visible_children(&visible, root.children, path, 1, allocator)
		}
	}

	return visible
}

// Helper to recursively collect visible children
@(private)
collect_visible_children :: proc(
	visible: ^[dynamic]Visible_Node,
	children: []^Tree_Node,
	parent_path: [dynamic]int,
	depth: int,
	allocator := context.allocator,
) {
	for child, i in children {
		if child == nil {
			continue
		}

		child_path := make([dynamic]int, allocator)
		for p in parent_path {
			append(&child_path, p)
		}
		append(&child_path, i)

		append(visible, Visible_Node{node = child, path = child_path, depth = depth})

		if child.expanded && len(child.children) > 0 {
			collect_visible_children(visible, child.children, child_path, depth + 1, allocator)
		}
	}
}

// Navigate to the next visible node.
//
// Returns nil, false when there is nowhere to go - the caller already holds
// the current path, and allocating a copy it is about to discard is how the
// idiomatic `if p, ok := navigate_down(...); ok` call site leaks.
navigate_down :: proc(
	roots: []^Tree_Node,
	current_path: []int,
	allocator := context.allocator,
) -> (new_path: [dynamic]int, ok: bool) {
	visible := get_visible_nodes(roots, allocator)
	defer destroy_visible_nodes(visible)

	// Find current position
	current_idx := -1
	for v, i in visible {
		if paths_equal(v.path[:], current_path) {
			current_idx = i
			break
		}
	}

	// Move to next
	if current_idx >= 0 && current_idx < len(visible) - 1 {
		next := visible[current_idx + 1]
		new_path = make([dynamic]int, allocator)
		for p in next.path {
			append(&new_path, p)
		}
		return new_path, true
	}

	// Nowhere to go: the caller keeps the path it already has.
	return nil, false
}

// Navigate to the previous visible node.
// Returns nil, false when there is nowhere to go; see navigate_down.
navigate_up :: proc(
	roots: []^Tree_Node,
	current_path: []int,
	allocator := context.allocator,
) -> (new_path: [dynamic]int, ok: bool) {
	visible := get_visible_nodes(roots, allocator)
	defer destroy_visible_nodes(visible)

	// Find current position
	current_idx := -1
	for v, i in visible {
		if paths_equal(v.path[:], current_path) {
			current_idx = i
			break
		}
	}

	// Move to previous
	if current_idx > 0 {
		prev := visible[current_idx - 1]
		new_path = make([dynamic]int, allocator)
		for p in prev.path {
			append(&new_path, p)
		}
		return new_path, true
	}

	// Nowhere to go: the caller keeps the path it already has.
	return nil, false
}

// Helper to compare paths
@(private)
paths_equal :: proc(a, b: []int) -> bool {
	if len(a) != len(b) {
		return false
	}
	for i in 0 ..< len(a) {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
