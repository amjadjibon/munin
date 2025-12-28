# Tree Component

The tree component provides hierarchical data visualization with expandable/collapsible nodes, perfect for displaying file systems, organizational structures, or any tree-like data.

## Features

- **Hierarchical Structure**: Support for unlimited nesting depth
- **Expandable Nodes**: Folders can be expanded/collapsed
- **Multiple Styles**: Line styles (Unicode, ASCII, dots, simple)
- **Selection Support**: Highlight and navigate through nodes
- **Custom Icons**: Support for custom icons or emoji
- **Styling Integration**: Works with Munin's styling system
- **Type Safety**: Different node types (Folder, File, Custom)

## Basic Usage

```odin
import "components"
import munin "munin"

// Create tree nodes
file1 := components.make_tree_node("main.odin", .File)
file2 := components.make_tree_node("utils.odin", .File)

children := []^components.Tree_Node{file1, file2}
folder := components.make_tree_node("src", .Folder, expanded = true, children = children)

roots := []^components.Tree_Node{folder}

// Draw the tree
config := components.default_tree_config()
components.draw_tree(buf, {0, 0}, roots, nil, config)
```

## Tree Node

### Creating Nodes

```odin
// Simple file node
file := components.make_tree_node("document.txt", .File)

// Folder with children
folder := components.make_tree_node(
    "my_folder",
    .Folder,
    expanded = true,
    children = []^components.Tree_Node{file},
)

// Custom styled node
custom := components.make_tree_node(
    "special",
    .Custom,
    color = .BrightMagenta,
    icon = "⭐",
)
```

### Node Types

- **`.Folder`**: Expandable container for child nodes
- **`.File`**: Leaf node (no children)
- **`.Custom`**: Custom node type with user-defined behavior

## Tree Styles

The tree component supports multiple drawing styles:

### Lines Style (Default)
```
📂 project
├── 📂 src
│   ├── 📄 main.odin
│   └── 📄 utils.odin
└── 📄 README.md
```

### ASCII Style
```
project
|-- src
|   |-- main.odin
|   +-- utils.odin
+-- README.md
```

### Dots Style
```
project
··· src
··· ··· main.odin
··· ··· utils.odin
··· README.md
```

### Simple Style
```
project
  src
    main.odin
    utils.odin
  README.md
```

## Configuration

```odin
config := components.Tree_Config{
    style = .Lines,              // Tree drawing style
    indent = 2,                  // Indentation width
    show_icons = true,           // Show/hide icons
    folder_open_icon = "📂",     // Icon for expanded folders
    folder_close_icon = "📁",    // Icon for collapsed folders
    file_icon = "📄",            // Icon for files
    line_color = .Gray,          // Color of tree lines
    folder_color = .BrightYellow,// Color of folder names
    file_color = .White,         // Color of file names
    selected_color = .BrightCyan,// Color of selected item
}
```

## Selection and Navigation

Track the selected node using a path (array of indices):

```odin
// Path to selected node: [root_idx, child_idx, grandchild_idx, ...]
selected_path := []int{0, 1, 2}  // root 0 -> child 1 -> grandchild 2

// Draw with selection
components.draw_tree(buf, {0, 0}, roots, selected_path, config)

// Find node at path
node := components.find_node_at_path(roots, selected_path)
```

### Tree Navigation

Use the built-in navigation functions to traverse visible nodes:

```odin
// Navigate down to next visible node
if new_path, ok := components.navigate_down(roots, current_path); ok {
    delete(current_path)
    current_path = new_path
}

// Navigate up to previous visible node
if new_path, ok := components.navigate_up(roots, current_path); ok {
    delete(current_path)
    current_path = new_path
}

// Get all currently visible nodes (respects expanded/collapsed state)
visible := components.get_visible_nodes(roots)
defer {
    for v in visible {
        delete(v.path)
    }
    delete(visible)
}

// Each visible node contains:
// - node: ^Tree_Node
// - path: [dynamic]int (path to this node)
// - depth: int (nesting depth)
```

**Important:** Navigation functions properly handle:
- Expanded/collapsed folder states
- Only traversing visible nodes
- Wrapping at boundaries
- Deep nesting

## Node Operations

### Toggle Expansion

```odin
// Toggle a single node
components.toggle_node(node)

// Expand all nodes recursively
components.expand_all(root_node)

// Collapse all nodes recursively
components.collapse_all(root_node)
```

## Styled Tree Rendering

Combine with Munin's styling system for beautiful bordered trees:

```odin
// Create a style
style := munin.new_style()
style = munin.style_border(style, munin.Border_Rounded)
style = munin.style_border_foreground(style, .BrightMagenta)
style = munin.style_padding(style, 1, 2, 1, 2)

// Render styled tree
output := components.render_tree_styled(
    roots,
    selected_path,
    config,
    style,
)
defer delete(output)  // Important: must delete returned string

fmt.println(output)
```

## Complete Example

```odin
package main

import "components"
import munin "munin"
import "core:strings"

Model :: struct {
    roots: []^components.Tree_Node,
    selected_path: []int,
}

init :: proc() -> Model {
    // Build file tree
    files := []^components.Tree_Node{
        components.make_tree_node("main.odin", .File),
        components.make_tree_node("types.odin", .File),
    }

    src := components.make_tree_node(
        "src",
        .Folder,
        expanded = true,
        children = files,
    )

    readme := components.make_tree_node("README.md", .File)

    roots := []^components.Tree_Node{src, readme}
    selected := []int{0}  // Select first item

    return Model{roots = roots, selected_path = selected}
}

view :: proc(model: Model, buf: ^strings.Builder) {
    munin.clear_screen(buf)

    config := components.default_tree_config()
    config.style = .Lines

    components.draw_tree(buf, {2, 2}, model.roots, model.selected_path, config)
}
```

## Tips

1. **Memory Management**: Tree nodes are allocated on the heap. Clean them up when done.

2. **Custom Icons**: Use emoji or Unicode symbols for custom icons:
   ```odin
   node.icon = "🔥"  // Fire icon
   node.icon = "⚡"  // Lightning icon
   node.icon = "📦"  // Package icon
   ```

3. **Performance**: For large trees, consider lazy loading children or virtual scrolling.

4. **Styling**: Use `render_tree_styled()` for one-off styled rendering, or `draw_tree()` for integration with existing view logic.

5. **Navigation**: Use the built-in navigation functions:
   ```odin
   case .Up:
       if new_path, ok := components.navigate_up(roots, current_path); ok {
           delete(current_path)
           current_path = new_path
       }
   case .Down:
       if new_path, ok := components.navigate_down(roots, current_path); ok {
           delete(current_path)
           current_path = new_path
       }
   ```

## API Reference

### Functions

```odin
// Create a tree node
make_tree_node :: proc(
    label: string,
    type: Tree_Node_Type = .File,
    expanded := false,
    children: []^Tree_Node = nil,
    color: munin.Color = .Reset,
    icon := "",
    allocator := context.allocator,
) -> ^Tree_Node

// Draw tree to buffer
draw_tree :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    roots: []^Tree_Node,
    selected_path: []int = nil,
    config := default_tree_config(),
) -> int

// Render styled tree
render_tree_styled :: proc(
    roots: []^Tree_Node,
    selected_path: []int = nil,
    config := default_tree_config(),
    style: munin.Style = {},
) -> string

// Node operations
toggle_node :: proc(node: ^Tree_Node)
expand_all :: proc(node: ^Tree_Node)
collapse_all :: proc(node: ^Tree_Node)
find_node_at_path :: proc(roots: []^Tree_Node, path: []int) -> ^Tree_Node

// Navigation
navigate_down :: proc(
    roots: []^Tree_Node,
    current_path: []int,
    allocator := context.allocator,
) -> (new_path: [dynamic]int, ok: bool)

navigate_up :: proc(
    roots: []^Tree_Node,
    current_path: []int,
    allocator := context.allocator,
) -> (new_path: [dynamic]int, ok: bool)

get_visible_nodes :: proc(
    roots: []^Tree_Node,
    allocator := context.allocator,
) -> [dynamic]Visible_Node
```

### Types

```odin
Tree_Node :: struct {
    label:     string,
    type:      Tree_Node_Type,
    expanded:  bool,
    children:  []^Tree_Node,
    icon:      string,
    color:     munin.Color,
    data:      rawptr,  // User data
}

Tree_Node_Type :: enum {
    Folder,
    File,
    Custom,
}

Tree_Style :: enum {
    Lines,   // ├──, └──, │
    Ascii,   // |-, +-, |
    Dots,    // ···
    Simple,  // No connectors
}

Visible_Node :: struct {
    node:  ^Tree_Node,
    path:  [dynamic]int,
    depth: int,
}
```

## See Also

- [List Component](LIST.md) - For flat lists
- [Styling Guide](STYLE.md) - For styling trees
- [Examples](../example/tree/) - Complete working example
