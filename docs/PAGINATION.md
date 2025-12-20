# Pagination Component

The Pagination component provides navigation controls for paginated content with multiple visual styles and helpful utilities for page calculation.

## Overview

Located in `components/pagination.odin`, this component offers flexible pagination controls for displaying and navigating through large datasets in terminal applications.

## Pagination Styles

### `Pagination_Style` enum

- **Numbers** - Traditional page numbers with arrows: `← 1 2 3 4 5 →`
- **Arrows** - Compact with page indicator: `← 3/10 →`
- **Dots** - Visual dots for each page: `• • ○ • •`
- **Compact** - Text-based: `Page 3 of 10 [←Prev] [Next→]`

## Functions

### `draw_pagination()`

Renders pagination controls with extensive customization.

```odin
draw_pagination :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    current_page: int,
    total_pages: int,
    style: Pagination_Style = .Numbers,
    max_visible: int = 7,
    active_color: munin.Color = munin.Basic_Color.BrightCyan,
    normal_color: munin.Color = munin.Basic_Color.White,
    disabled_color: munin.Color = munin.Basic_Color.BrightBlue,
)
```

**Parameters:**
- `buf` - String builder for output
- `pos` - Position to draw pagination
- `current_page` - Current page number (1-based)
- `total_pages` - Total number of pages
- `style` - Visual style (default: `.Numbers`)
- `max_visible` - Maximum visible page numbers in `.Numbers` style (default: 7)
- `active_color` - Color for current page (default: `munin.Basic_Color.BrightCyan`)
- `normal_color` - Color for other pages (default: `munin.Basic_Color.White`)
- `disabled_color` - Color for disabled navigation (default: `munin.Basic_Color.BrightBlue`)

**Features:**
- Automatically disables prev/next arrows at boundaries
- Ellipsis (`...`) for truncated page ranges
- Current page is bold and highlighted
- Responsive to available space

**Example:**
```odin
draw_pagination(&buf, {10, 20}, 5, 20, .Numbers)
```

---

### `draw_pagination_with_info()`

Renders pagination with additional item count information.

```odin
draw_pagination_with_info :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    current_page: int,
    total_pages: int,
    items_per_page: int,
    total_items: int,
    style: Pagination_Style = .Numbers,
)
```

**Parameters:**
- `buf` - String builder for output
- `pos` - Position to draw pagination
- `current_page` - Current page (1-based)
- `total_pages` - Total pages
- `items_per_page` - Items shown per page
- `total_items` - Total item count
- `style` - Visual style

**Features:**
- Shows pagination controls
- Displays item range: "Showing 41-50 of 237 items"
- Info appears 2 lines below pagination

**Example:**
```odin
draw_pagination_with_info(&buf, {10, 20}, 5, 24, 10, 237, .Numbers)
```
Output:
```
← 1 ... 3 4 5 6 7 ... 24 →

Showing 41-50 of 237 items
```

---

### `calculate_pages()`

Calculates total pages from item count and page size.

```odin
calculate_pages :: proc(total_items, items_per_page: int) -> int
```

**Parameters:**
- `total_items` - Total number of items
- `items_per_page` - Items per page

**Returns:** Number of pages needed (rounded up)

**Example:**
```odin
pages := calculate_pages(237, 10)  // Returns 24
pages := calculate_pages(100, 10)  // Returns 10
pages := calculate_pages(101, 10)  // Returns 11
```

---

### `get_page_slice()`

Extracts the items for a specific page from an array.

```odin
get_page_slice :: proc(
    items: $T/[]$E,
    current_page: int,
    items_per_page: int,
) -> T
```

**Parameters:**
- `items` - Full array of items
- `current_page` - Page to extract (1-based)
- `items_per_page` - Items per page

**Returns:** Slice of items for the requested page

**Features:**
- Generic function works with any array type
- Handles bounds automatically
- Returns empty slice for invalid pages

**Example:**
```odin
all_users := []User{ /* 100 users */ }
page_users := get_page_slice(all_users, 3, 10)  // Returns users 21-30
```

## Usage Examples

### Basic Number Pagination

```odin
import "components"
import "core:strings"

buf := strings.builder_make()
defer strings.builder_destroy(&buf)

components.draw_pagination(
    &buf,
    {10, 20},
    5,        // Current page
    20,       // Total pages
    .Numbers,
)
```
Output: `← 1 2 3 4 5 6 7 ... 20 →`

### Arrow Style (Compact)

```odin
components.draw_pagination(
    &buf,
    {10, 20},
    3,
    10,
    .Arrows,
)
```
Output: `← 3/10 →`

### Dots Style

```odin
components.draw_pagination(
    &buf,
    {10, 20},
    3,
    5,
    .Dots,
)
```
Output: `○ ○ ● ○ ○`

### Compact Style

```odin
components.draw_pagination(
    &buf,
    {10, 20},
    7,
    15,
    .Compact,
)
```
Output: `Page 7 of 15  [←Prev] [Next→]`

### Pagination with Item Info

```odin
current_page := 5
items_per_page := 10
total_items := 237

total_pages := components.calculate_pages(total_items, items_per_page)

components.draw_pagination_with_info(
    &buf,
    {10, 20},
    current_page,
    total_pages,
    items_per_page,
    total_items,
    .Numbers,
)
```
Output:
```
← 1 ... 3 4 5 6 7 ... 24 →

Showing 41-50 of 237 items
```

### Complete Pagination System

```odin
Paginated_View :: struct {
    items: []Item,
    current_page: int,
    items_per_page: int,
}

get_visible_items :: proc(view: ^Paginated_View) -> []Item {
    return components.get_page_slice(
        view.items,
        view.current_page,
        view.items_per_page,
    )
}

get_total_pages :: proc(view: ^Paginated_View) -> int {
    return components.calculate_pages(
        len(view.items),
        view.items_per_page,
    )
}

draw_paginated_content :: proc(view: ^Paginated_View, buf: ^strings.Builder) {
    // Draw items for current page
    visible_items := get_visible_items(view)
    for item, i in visible_items {
        // ... draw item ...
    }

    // Draw pagination controls
    total_pages := get_total_pages(view)
    components.draw_pagination_with_info(
        buf,
        {5, 25},
        view.current_page,
        total_pages,
        view.items_per_page,
        len(view.items),
        .Numbers,
    )
}
```

### Navigation Handling

```odin
handle_pagination_input :: proc(
    current_page: ^int,
    total_pages: int,
    key: Key,
) {
    switch key {
    case .Left, .Comma:
        // Previous page
        current_page^ = max(1, current_page^ - 1)

    case .Right, .Period:
        // Next page
        current_page^ = min(total_pages, current_page^ + 1)

    case .Home:
        // First page
        current_page^ = 1

    case .End:
        // Last page
        current_page^ = total_pages

    case .PageUp:
        // Jump back 10 pages
        current_page^ = max(1, current_page^ - 10)

    case .PageDown:
        // Jump forward 10 pages
        current_page^ = min(total_pages, current_page^ + 10)
    }
}
```

### Responsive Pagination

```odin
get_appropriate_style :: proc(
    total_pages: int,
    available_width: int,
) -> components.Pagination_Style {
    if total_pages <= 5 {
        return .Numbers  // Show all numbers
    } else if available_width < 30 {
        return .Arrows   // Compact for narrow screens
    } else if available_width < 50 {
        return .Compact  // Medium width
    } else {
        return .Numbers  // Full pagination
    }
}
```

## Visual Reference

### Numbers Style (max_visible = 7)
```
← 1 2 3 4 5 6 7 ... 24 →        // Pages 1-7 visible
← 1 ... 8 9 10 11 12 ... 24 →   // Middle pages
← 1 ... 18 19 20 21 22 23 24 →  // Last pages visible
```

### Numbers Style - First Page
```
1 2 3 4 5 6 7 ... 24 →           // No left arrow (disabled)
```

### Numbers Style - Last Page
```
← 1 ... 18 19 20 21 22 23 24     // No right arrow (disabled)
```

### Arrows Style
```
← 1/10 →                         // Simple and compact
```

### Dots Style
```
○ ○ ● ○ ○                        // Page 3 of 5
```

### Compact Style
```
Page 3 of 10  [←Prev] [Next→]
Page 1 of 10  [Next→]            // First page (no prev)
Page 10 of 10  [←Prev]           // Last page (no next)
```

## Best Practices

1. **Page numbering** - Always use 1-based page numbers for user display
2. **Bounds checking** - Validate page numbers before updating state
3. **Style selection** - Choose style based on available space and page count
4. **Color coding** - Use `disabled_color` for unavailable navigation
5. **Keyboard shortcuts** - Support multiple keys for same action (arrows + vim keys)
6. **Item count display** - Show total items when using `.draw_pagination_with_info()`
7. **Max visible pages** - Use `max_visible = 5` for narrow displays, `7` for normal, `9` for wide

## Common Patterns

### Search Results Pagination
```odin
draw_search_results :: proc(results: []SearchResult, page: int) {
    items_per_page := 10
    total_pages := components.calculate_pages(len(results), items_per_page)

    // Get current page items
    page_results := components.get_page_slice(results, page, items_per_page)

    // Draw results
    for result, i in page_results {
        // ... render result ...
    }

    // Pagination with info
    components.draw_pagination_with_info(
        buf, {0, 30}, page, total_pages,
        items_per_page, len(results), .Numbers,
    )
}
```

### Table Pagination
```odin
draw_table_with_pagination :: proc(
    data: [][]string,
    page: int,
    rows_per_page: int,
) {
    total_pages := components.calculate_pages(len(data), rows_per_page)
    page_data := components.get_page_slice(data, page, rows_per_page)

    // Draw table
    components.draw_table(buf, {5, 5}, columns, page_data)

    // Draw pagination below table
    components.draw_pagination(
        buf, {5, 20}, page, total_pages, .Numbers,
    )
}
```

## Integration

Requires:
- `munin` package for colors and cursor positioning
- `core:strings` for string building
- `core:fmt` for number formatting

## Notes

- All page numbers are 1-based for user-facing display
- `total_pages = 0` is handled gracefully (no output)
- Ellipsis appears when page count exceeds `max_visible`
- First and last pages are always shown in `.Numbers` style when using ellipsis
- Colors automatically adjust for disabled states (first/last page)
- `get_page_slice()` safely handles out-of-bounds requests
