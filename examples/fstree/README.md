# File System Tree Viewer

A full-featured TUI implementation of the `tree` command that displays your file system in an interactive, navigable tree view.

## Features

✨ **Real File System Navigation**
- Browse actual directories and files
- Lazy loading of directory contents
- Start from current directory or jump to home

🎨 **Beautiful Color Scheme** (Hex RGB Colors)
- 📂 Directories: `#64C8FF` (Bright Teal)
- 📘 `.odin` files: `#8AB4F8` (Soft Blue)
- 📝 Markdown/Text: `#FFD764` (Golden Yellow)
- 📋 JSON/YAML/TOML: `#98E098` (Soft Green)
- 🔴 Shell scripts: `#FF8A8A` (Soft Red)
- 💜 C/C++ files: `#868EFF` (Purple)
- 🐍 Python files: `#64B4FF` (Python Blue)
- ⚡ JavaScript/TypeScript: `#F0DB4F` (JS Yellow)
- 🦀 Rust files: `#CE9178` (Rust Orange)
- 🎯 Go files: `#00ADD8` (Go Cyan)
- 🖼️ Images: `#FF8CFF` (Magenta)
- 🎵 Audio: `#B48EFF` (Purple)
- 🎬 Video: `#FFA564` (Orange)
- 📦 Archives: `#C864FF` (Purple)
- 📄 PDF: `#FF6464` (Red)
- 👻 Hidden files: `#787882` (Dim Gray)
- Other files: `#C8C8D2` (Light Gray)

📊 **File Information**
- File sizes with smart formatting (B, KB, MB, GB)
- Toggle size display on/off
- Toggle hidden files (starting with `.`)
- Full path display in status bar
- Real-time toggle status indicators

⌨️ **Interactive Controls**
- Arrow keys for navigation
- Space/→ to expand folders
- Lazy loading: directories load only when expanded
- Home: Jump to home directory
- Refresh: Reload current directory

## Building and Running

```bash
cd example/fstree
odin run main.odin -file
```

Or build and run:
```bash
odin build main.odin -file -out:fstree
./fstree
```

## Keyboard Controls

| Key | Action |
|-----|--------|
| ↑/↓ | Navigate up/down through visible items |
| Space | Expand/collapse selected folder |
| → | Expand selected folder |
| ← | Collapse selected folder |
| H | Go to home directory |
| R | Refresh current directory |
| S | Toggle file size display |
| . | Toggle hidden files (starting with `.`) |
| Q | Quit |

## How It Works

### 1. **Initialization**
- Starts in the current working directory
- Reads all files and folders
- Sorts: directories first, then alphabetically
- Creates tree nodes for each entry

### 2. **Lazy Loading**
- Folders start collapsed (no children loaded)
- When you expand a folder, its contents are loaded on-demand
- This keeps memory usage low for large directory structures

### 3. **Smart Rendering**
- Uses the tree component's proper navigation
- Respects expanded/collapsed state
- Shows file sizes next to each file
- Highlights the selected item with bright green
- Beautiful hex color scheme for all file types
- Dim gray for hidden files when visible

### 4. **File Size Formatting**
- Less than 1KB: Shows in bytes (e.g., "256B")
- Less than 1MB: Shows in KB (e.g., "12.5K")
- Less than 1GB: Shows in MB (e.g., "3.2M")
- 1GB or more: Shows in GB (e.g., "1.5G")

### 5. **Hidden Files Toggle**
- Press `.` to toggle visibility of hidden files (starting with `.`)
- Rebuilds entire tree when toggled
- Hidden files shown in dim gray when visible
- Toggle state shown in bottom status bar

## Code Structure

```odin
// File metadata stored in each node
File_Info :: struct {
    path:      string,
    size:      i64,
    is_dir:    bool,
    is_hidden: bool,
}

// Main application state
Model :: struct {
    roots:         []^Tree_Node,
    selected_path: [dynamic]int,
    current_dir:   string,
    show_hidden:   bool,
    show_size:     bool,
    error_msg:     string,
}
```

### Key Functions

**`build_directory_tree()`**
- Reads a directory from the file system
- Creates tree nodes for all entries
- Filters hidden files based on `show_hidden` setting
- Sorts: directories first, then alphabetically

**`load_directory_children()`**
- Lazy loads children when a folder is expanded
- Respects `show_hidden` setting
- Only loads once per folder (until tree is rebuilt)
- Handles errors gracefully

**`create_node_from_file_info()`**
- Creates tree nodes with beautiful hex colors
- Over 20 file type color mappings
- Special handling for hidden files
- Assigns appropriate icons and labels

**`draw_tree_with_sizes()`**
- Custom rendering to show file sizes
- Extends the base tree component
- Preserves all tree formatting (lines, colors, etc.)

## Example Output

```
📂 my_project
├── 📂 src
│   ├── 📄 main.odin (2.3K)
│   ├── 📄 types.odin (1.8K)
│   └── 📄 utils.odin (3.1K)
├── 📂 tests
│   └── 📄 main_test.odin (1.2K)
├── 📄 README.md (4.5K)
└── 📄 LICENSE (1.1K)
```

## Performance Considerations

**Memory Efficient**
- Lazy loading means only expanded directories are in memory
- Large file systems remain fast and responsive

**Smart Updates**
- Refresh only reloads the current directory
- Navigation uses efficient path-based lookups

**Responsive UI**
- 60 FPS rendering by default
- Event-driven updates (only redraws on changes)

## Extending the Viewer

### Add File Type Icons

```odin
// In create_node_from_file_info()
switch ext {
case ".odin":
    node.icon = "📘"
case ".md":
    node.icon = "📝"
case ".json":
    node.icon = "📋"
// ... more types
}
```

### Add File Permissions

```odin
File_Info :: struct {
    // ... existing fields
    permissions: os.File_Mode,
}

// Display in status bar or next to filename
```

### Add Search Functionality

```odin
// Add to Model
search_query: string,
search_results: []^Tree_Node,

// Filter nodes based on query
// Highlight matching nodes
```

## Dependencies

- `munin` - The TUI framework
- `components` - Tree component
- `core:os` - File system access
- `core:path/filepath` - Path manipulation

## See Also

- [Tree Component Documentation](../../docs/TREE.md)
- [Simple Tree Example](../tree/)
- [Munin Documentation](../../README.md)
