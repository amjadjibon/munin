# List Component

The List component provides flexible list rendering with various marker styles, selection highlighting, and scrollable viewports.

## Overview

Located in `components/list.odin`, this component enables rendering of lists with different marker types, selection states, and scrolling capabilities for terminal interfaces.

## List Styles

### `List_Style` enum

- **Bullet** - Bullet point markers (`•`)
- **Number** - Numbered list (1. 2. 3. ...)
- **Arrow** - Arrow markers (`→`)
- **Checkbox** - Checkboxes (`[✓]` or `[ ]`)
- **Custom** - Custom marker string

## Data Structures

### `List_Item`

Represents a single item in the list:

```odin
List_Item :: struct {
    text:    string,
    checked: bool,           // For checkbox style
    color:   munin.Color,    // Item color
}
```

**Fields:**
- `text` - The display text for the item
- `checked` - Whether the checkbox is checked (only used with `.Checkbox` style)
- `color` - Text color for this item (`.Reset` uses default)

## Functions

### `draw_list()`

Renders a list with various styling options.

```odin
draw_list :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    items: []List_Item,
    selected: int = -1,
    style: List_Style = .Bullet,
    custom_marker: string = "",
    selected_color: munin.Color = munin.Basic_Color.BrightYellow,
    indent: int = 2,
)
```

**Parameters:**
- `buf` - String builder for output
- `pos` - Starting position for the list
- `items` - Array of list items to render
- `selected` - Index of selected item (-1 for none)
- `style` - List marker style (default: `.Bullet`)
- `custom_marker` - Custom marker when style is `.Custom`
- `selected_color` - Color for the selected item
- `indent` - Indentation spacing (default: 2)

**Features:**
- Selected items are prefixed with `►` symbol
- Selected items are rendered in bold with `selected_color`
- Each style has appropriate marker spacing
- Items can have individual colors

**Example:**
```odin
items := []List_Item{
    {text = "Apple", color = .Green},
    {text = "Banana", color = .Yellow},
    {text = "Cherry", color = .Red},
}

draw_list(&buf, {5, 5}, items, 1, .Bullet, "", .BrightYellow)
```

---

### `draw_list_scrollable()`

Renders a scrollable list with viewport management and scroll indicators.

```odin
draw_list_scrollable :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    visible_height: int,
    items: []List_Item,
    selected: int,
    scroll_offset: int,
    style: List_Style = .Bullet,
)
```

**Parameters:**
- `buf` - String builder for output
- `pos` - Starting position
- `visible_height` - Number of items visible in the viewport
- `items` - Full array of list items
- `selected` - Currently selected item index (in full list)
- `scroll_offset` - First visible item index
- `style` - List marker style

**Features:**
- Displays only items within the viewport
- Shows "▲ More above" indicator when scrolled down
- Shows "▼ More below" indicator when more items exist below
- Automatically adjusts selected index for visible range
- Useful for long lists that don't fit on screen

**Example:**
```odin
draw_list_scrollable(
    &buf,
    {5, 5},
    10,              // Show 10 items at a time
    all_items,       // Array of 100 items
    selected_idx,    // Currently selected: 25
    scroll_offset,   // Start showing from: 20
    .Number,
)
```

## Usage Examples

### Basic Bullet List

```odin
import "components"
import "core:strings"

buf := strings.builder_make()
defer strings.builder_destroy(&buf)

items := []components.List_Item{
    {text = "First item", color = .White},
    {text = "Second item", color = .White},
    {text = "Third item", color = .White},
}

components.draw_list(&buf, {5, 5}, items, -1, .Bullet)
```

Output:
```
• First item
• Second item
• Third item
```

### Numbered List with Selection

```odin
items := []components.List_Item{
    {text = "Introduction", color = .BrightCyan},
    {text = "Installation", color = .BrightCyan},
    {text = "Usage", color = .BrightCyan},
}

// Select the second item (index 1)
components.draw_list(&buf, {5, 5}, items, 1, .Number, "", .BrightYellow)
```

Output:
```
1. Introduction
► 2. Installation  // Bold and yellow
3. Usage
```

### Checkbox Todo List

```odin
todos := []components.List_Item{
    {text = "Buy groceries", checked = true, color = .White},
    {text = "Write documentation", checked = false, color = .White},
    {text = "Review code", checked = true, color = .White},
}

components.draw_list(&buf, {5, 5}, todos, -1, .Checkbox)
```

Output:
```
[✓] Buy groceries
[ ] Write documentation
[✓] Review code
```

### Custom Marker List

```odin
items := []components.List_Item{
    {text = "Error: File not found", color = .Red},
    {text = "Warning: Deprecated API", color = .Yellow},
    {text = "Info: Process complete", color = .Blue},
}

components.draw_list(&buf, {5, 5}, items, -1, .Custom, "⚠")
```

Output:
```
⚠ Error: File not found
⚠ Warning: Deprecated API
⚠ Info: Process complete
```

### Arrow List for Navigation

```odin
menu_items := []components.List_Item{
    {text = "Settings", color = .BrightWhite},
    {text = "Profile", color = .BrightWhite},
    {text = "Logout", color = .BrightRed},
}

components.draw_list(&buf, {10, 10}, menu_items, 0, .Arrow, "", .BrightCyan)
```

Output:
```
► → Settings  // Bold and cyan (selected)
→ Profile
→ Logout
```

### Scrollable List Implementation

```odin
// Full item list (e.g., 100 items)
all_items := make_large_item_list()

// Track scroll state
scroll_offset := 0
selected := 0
visible_height := 10

// Scroll management
ensure_visible_in_viewport :: proc(selected, scroll_offset, visible_height: int) -> int {
    new_offset := scroll_offset

    // Scroll down if selected is below viewport
    if selected >= scroll_offset + visible_height {
        new_offset = selected - visible_height + 1
    }

    // Scroll up if selected is above viewport
    if selected < scroll_offset {
        new_offset = selected
    }

    return max(0, new_offset)
}

// Update scroll position based on selection
scroll_offset = ensure_visible_in_viewport(selected, scroll_offset, visible_height)

// Draw the scrollable list
components.draw_list_scrollable(
    &buf,
    {5, 5},
    visible_height,
    all_items,
    selected,
    scroll_offset,
    .Number,
)
```

### Interactive Menu

```odin
Menu_State :: struct {
    items: []components.List_Item,
    selected: int,
}

handle_menu_input :: proc(state: ^Menu_State, key: Key) {
    switch key {
    case .Up:
        state.selected = max(0, state.selected - 1)
    case .Down:
        state.selected = min(len(state.items) - 1, state.selected + 1)
    case .Enter:
        execute_menu_item(state.selected)
    }
}

draw_menu :: proc(state: ^Menu_State, buf: ^strings.Builder) {
    components.draw_list(
        buf,
        {10, 5},
        state.items,
        state.selected,
        .Arrow,
        "",
        .BrightYellow,
    )
}
```

## Visual Reference

### Bullet Style
```
• First item
► • Second item (selected)
• Third item
```

### Number Style
```
1. First item
► 2. Second item (selected)
3. Third item
```

### Arrow Style
```
→ First item
► → Second item (selected)
→ Third item
```

### Checkbox Style
```
[✓] Completed task
[ ] Pending task
► [✓] Selected completed task
```

### Scrollable List with Indicators
```
         ▲ More above
► 21. Item twenty-one
22. Item twenty-two
23. Item twenty-three
24. Item twenty-four
25. Item twenty-five
         ▼ More below
```

## Best Practices

1. **Selection management** - Keep selected index within valid range `[0, len(items))`
2. **Color consistency** - Use consistent colors for similar item types
3. **Checkbox usage** - Use checkbox style only for items with boolean state
4. **Custom markers** - Keep custom markers short (1-3 characters) for proper alignment
5. **Scrolling** - Update scroll offset when selection changes to keep selected item visible
6. **Empty lists** - Handle empty item arrays gracefully in your UI logic
7. **Performance** - For large lists (>1000 items), use `draw_list_scrollable()` to render only visible items

## Keyboard Navigation Pattern

```odin
// Common keyboard navigation for lists
handle_list_navigation :: proc(selected: ^int, item_count: int, key: Key) {
    switch key {
    case .Up, .K:      // k for vim-style
        selected^ = max(0, selected^ - 1)
    case .Down, .J:    // j for vim-style
        selected^ = min(item_count - 1, selected^ + 1)
    case .Home, .G:    // G for vim-style (first)
        selected^ = 0
    case .End:         // Shift+G for vim-style (last)
        selected^ = item_count - 1
    case .PageUp:
        selected^ = max(0, selected^ - 10)
    case .PageDown:
        selected^ = min(item_count - 1, selected^ + 10)
    }
}
```

## Integration

Requires:
- `munin` package for colors and cursor positioning
- `core:strings` for string building
- `core:fmt` for number formatting

## Notes

- List items are rendered top-to-bottom, one per line
- Selection indicator (`►`) adds 2 characters to the left
- Markers have variable width (• is 1 char, [✓] is 3 chars)
- Text after markers is automatically spaced for alignment
- Scroll indicators appear at fixed positions relative to the list
