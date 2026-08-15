package components

import munin ".."
import "core:mem"
import "core:strings"
import "core:testing"

// Build a small tree:
//   root (folder, expanded)
//     child_a (file)
//     sub (folder, collapsed)
//       leaf (file)
@(private = "file")
make_fixture :: proc(
	allocator := context.allocator,
) -> (
	roots: []^Tree_Node,
	nodes: [dynamic]^Tree_Node,
) {
	nodes = make([dynamic]^Tree_Node, allocator)

	leaf := make_tree_node("leaf", .File, allocator = allocator)
	append(&nodes, leaf)

	sub_children := make([]^Tree_Node, 1, allocator)
	sub_children[0] = leaf
	sub := make_tree_node("sub", .Folder, false, sub_children, allocator = allocator)
	append(&nodes, sub)

	child_a := make_tree_node("child_a", .File, allocator = allocator)
	append(&nodes, child_a)

	root_children := make([]^Tree_Node, 2, allocator)
	root_children[0] = child_a
	root_children[1] = sub
	root := make_tree_node("root", .Folder, true, root_children, allocator = allocator)
	append(&nodes, root)

	root_slice := make([]^Tree_Node, 1, allocator)
	root_slice[0] = root
	return root_slice, nodes
}

@(private = "file")
destroy_fixture :: proc(roots: []^Tree_Node, nodes: [dynamic]^Tree_Node) {
	for n in nodes {
		delete(n.children)
		free(n)
	}
	delete(nodes)
	delete(roots)
}

// ============================================================
// NODE CONSTRUCTION AND STATE
// ============================================================

@(test)
test_make_tree_node_defaults :: proc(t: ^testing.T) {
	node := make_tree_node("file.txt")
	defer free(node)

	testing.expect_value(t, node.label, "file.txt")
	testing.expect_value(t, node.type, Tree_Node_Type.File)
	testing.expect_value(t, node.expanded, false)
	testing.expect_value(t, len(node.children), 0)
}

@(test)
test_toggle_node_only_affects_folders :: proc(t: ^testing.T) {
	folder := make_tree_node("dir", .Folder)
	defer free(folder)
	file := make_tree_node("f", .File)
	defer free(file)

	toggle_node(folder)
	testing.expect_value(t, folder.expanded, true)
	toggle_node(folder)
	testing.expect_value(t, folder.expanded, false)

	toggle_node(file)
	testing.expect_value(t, file.expanded, false)
}

@(test)
test_toggle_node_nil_is_safe :: proc(t: ^testing.T) {
	toggle_node(nil)
	expand_all(nil)
	collapse_all(nil)
}

@(test)
test_expand_and_collapse_all :: proc(t: ^testing.T) {
	roots, nodes := make_fixture()
	defer destroy_fixture(roots, nodes)

	expand_all(roots[0])
	for n in nodes {
		if n.type == .Folder {
			testing.expectf(t, n.expanded, "%s should be expanded", n.label)
		}
	}

	collapse_all(roots[0])
	for n in nodes {
		if n.type == .Folder {
			testing.expectf(t, !n.expanded, "%s should be collapsed", n.label)
		}
	}
}

// ============================================================
// PATH LOOKUP
// ============================================================

@(test)
test_find_node_at_path :: proc(t: ^testing.T) {
	roots, nodes := make_fixture()
	defer destroy_fixture(roots, nodes)

	testing.expect_value(t, find_node_at_path(roots, {0}).label, "root")
	testing.expect_value(t, find_node_at_path(roots, {0, 0}).label, "child_a")
	testing.expect_value(t, find_node_at_path(roots, {0, 1}).label, "sub")
	testing.expect_value(t, find_node_at_path(roots, {0, 1, 0}).label, "leaf")
}

@(test)
test_find_node_at_path_rejects_bad_paths :: proc(t: ^testing.T) {
	roots, nodes := make_fixture()
	defer destroy_fixture(roots, nodes)

	testing.expect(t, find_node_at_path(roots, {}) == nil, "Empty path")
	testing.expect(t, find_node_at_path(roots, {5}) == nil, "Root index out of range")
	testing.expect(t, find_node_at_path(roots, {0, 9}) == nil, "Child index out of range")
	testing.expect(t, find_node_at_path(roots, {0, 0, 0}) == nil, "Path through a leaf")
}

@(test)
test_find_node_at_path_rejects_negative_indices :: proc(t: ^testing.T) {
	// Regression: a negative index read before the start of the slice.
	roots, nodes := make_fixture()
	defer destroy_fixture(roots, nodes)

	testing.expect(t, find_node_at_path(roots, {-1}) == nil, "Negative root index")
	testing.expect(t, find_node_at_path(roots, {0, -1}) == nil, "Negative child index")
}

// ============================================================
// VISIBLE NODES AND NAVIGATION
// ============================================================

@(test)
test_get_visible_nodes_respects_collapsed_state :: proc(t: ^testing.T) {
	roots, nodes := make_fixture()
	defer destroy_fixture(roots, nodes)

	visible := get_visible_nodes(roots)
	defer {
		for v in visible {delete(v.path)}
		delete(visible)
	}

	// root + child_a + sub, but not leaf (sub is collapsed)
	testing.expect_value(t, len(visible), 3)
	testing.expect_value(t, visible[0].node.label, "root")
	testing.expect_value(t, visible[1].node.label, "child_a")
	testing.expect_value(t, visible[2].node.label, "sub")
	testing.expect_value(t, visible[0].depth, 0)
	testing.expect_value(t, visible[1].depth, 1)
}

@(test)
test_get_visible_nodes_after_expand :: proc(t: ^testing.T) {
	roots, nodes := make_fixture()
	defer destroy_fixture(roots, nodes)

	expand_all(roots[0])

	visible := get_visible_nodes(roots)
	defer {
		for v in visible {delete(v.path)}
		delete(visible)
	}

	testing.expect_value(t, len(visible), 4)
	testing.expect_value(t, visible[3].node.label, "leaf")
	testing.expect_value(t, visible[3].depth, 2)
}

@(test)
test_get_visible_nodes_skips_nil_roots :: proc(t: ^testing.T) {
	roots := []^Tree_Node{nil}

	visible := get_visible_nodes(roots)
	defer {
		for v in visible {delete(v.path)}
		delete(visible)
	}

	testing.expect_value(t, len(visible), 0)
}

@(test)
test_navigate_down_and_up :: proc(t: ^testing.T) {
	roots, nodes := make_fixture()
	defer destroy_fixture(roots, nodes)

	down, ok := navigate_down(roots, {0})
	defer delete(down)
	testing.expect(t, ok, "Should move down from the root")
	testing.expect_value(t, find_node_at_path(roots, down[:]).label, "child_a")

	up, up_ok := navigate_up(roots, down[:])
	defer delete(up)
	testing.expect(t, up_ok, "Should move back up")
	testing.expect_value(t, find_node_at_path(roots, up[:]).label, "root")
}

@(test)
test_navigate_stops_at_edges :: proc(t: ^testing.T) {
	roots, nodes := make_fixture()
	defer destroy_fixture(roots, nodes)

	// Already at the first visible node
	up, up_ok := navigate_up(roots, {0})
	testing.expect(t, !up_ok, "Cannot move above the first node")
	testing.expect_value(t, len(up), 0)

	// Last visible node is "sub" at {0,1}
	down, down_ok := navigate_down(roots, {0, 1})
	testing.expect(t, !down_ok, "Cannot move below the last node")
	testing.expect_value(t, len(down), 0)
}

@(test)
test_navigate_does_not_allocate_when_it_cannot_move :: proc(t: ^testing.T) {
	// Regression: both procedures used to allocate a copy of the current path
	// on the no-op path and return it with ok = false, so the idiomatic
	// `if p, ok := navigate_up(...); ok { }` call site leaked one path per
	// keypress at the edge of the tree.
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	tracked := mem.tracking_allocator(&track)

	roots, nodes := make_fixture()
	defer destroy_fixture(roots, nodes)

	for _ in 0 ..< 20 {
		if p, ok := navigate_up(roots, {0}, tracked); ok {
			delete(p)
		}
		if p, ok := navigate_down(roots, {0, 1}, tracked); ok {
			delete(p)
		}
	}

	testing.expectf(
		t,
		len(track.allocation_map) == 0,
		"leaked %d allocations navigating at the edges",
		len(track.allocation_map),
	)
}

@(test)
test_destroy_visible_nodes_frees_every_path :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	tracked := mem.tracking_allocator(&track)

	roots, nodes := make_fixture()
	defer destroy_fixture(roots, nodes)
	expand_all(roots[0])

	visible := get_visible_nodes(roots, tracked)
	testing.expect_value(t, len(visible), 4)
	destroy_visible_nodes(visible)

	testing.expectf(
		t,
		len(track.allocation_map) == 0,
		"destroy_visible_nodes left %d allocations",
		len(track.allocation_map),
	)
}

@(test)
test_navigate_with_unknown_path :: proc(t: ^testing.T) {
	roots, nodes := make_fixture()
	defer destroy_fixture(roots, nodes)

	down, ok := navigate_down(roots, {7, 7})
	defer delete(down)
	testing.expect(t, !ok, "Unknown path should not navigate")
}

// ============================================================
// RENDERING
// ============================================================

@(test)
test_draw_tree_renders_visible_labels :: proc(t: ^testing.T) {
	roots, nodes := make_fixture()
	defer destroy_fixture(roots, nodes)

	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	config := default_tree_config()
	lines := draw_tree(&buf, {0, 0}, roots, nil, config)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect_value(t, lines, 3)
	testing.expect(t, strings.contains(out, "root"), "Root label")
	testing.expect(t, strings.contains(out, "child_a"), "Child label")
	testing.expect(t, !strings.contains(out, "leaf"), "Collapsed child stays hidden")
	free_all(context.temp_allocator)
}

@(test)
test_draw_tree_connectors_per_style :: proc(t: ^testing.T) {
	roots, nodes := make_fixture()
	defer destroy_fixture(roots, nodes)

	config := default_tree_config()
	config.style = .Ascii

	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	draw_tree(&buf, {0, 0}, roots, nil, config)
	out := munin.strip_ansi(strings.to_string(buf))

	testing.expect(t, strings.contains(out, "|--") || strings.contains(out, "+--"), "ASCII connectors")
	free_all(context.temp_allocator)
}

@(test)
test_draw_tree_all_styles_render :: proc(t: ^testing.T) {
	roots, nodes := make_fixture()
	defer destroy_fixture(roots, nodes)
	expand_all(roots[0])

	for style in Tree_Style {
		config := default_tree_config()
		config.style = style

		buf := strings.builder_make()
		defer strings.builder_destroy(&buf)

		lines := draw_tree(&buf, {0, 0}, roots, {0, 1}, config)
		testing.expectf(t, lines == 4, "%v should draw 4 lines, drew %d", style, lines)
	}
	free_all(context.temp_allocator)
}

@(test)
test_draw_tree_handles_nil_node :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	roots := []^Tree_Node{nil}
	lines := draw_tree(&buf, {0, 0}, roots, nil, default_tree_config())
	testing.expect_value(t, lines, 0)
}

@(test)
test_render_tree_styled_plain :: proc(t: ^testing.T) {
	roots, nodes := make_fixture()
	defer destroy_fixture(roots, nodes)

	out := render_tree_styled(roots, nil, default_tree_config(), munin.new_style())
	defer delete(out)

	testing.expect(t, strings.contains(munin.strip_ansi(out), "root"), "Should contain the tree")
	free_all(context.temp_allocator)
}

@(test)
test_render_tree_styled_with_border :: proc(t: ^testing.T) {
	roots, nodes := make_fixture()
	defer destroy_fixture(roots, nodes)

	style := munin.style_border(munin.new_style(), munin.Border_Normal)
	out := render_tree_styled(roots, nil, default_tree_config(), style)
	defer delete(out)

	testing.expect(t, strings.contains(out, "┌"), "Should apply the border style")
	free_all(context.temp_allocator)
}
