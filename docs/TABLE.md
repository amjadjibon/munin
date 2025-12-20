# Table Component

The Table component provides structured data display with column alignment, headers, and Unicode box-drawing borders.

## Overview

Located in `components/table.odin`, this component enables rendering of tabular data with customizable column widths, alignment options, and styled borders.

## Data Structures

### `Table_Align` enum

Column alignment options:

- **Left** - Align content to the left
- **Center** - Center content within column
- **Right** - Align content to the right

### `Table_Column`

Column definition structure:

```odin
Table_Column :: struct {
    title: string,        // Column header text
    width: int,           // Column width in characters
    align: Table_Align,   // Text alignment
}
```

## Functions

### `draw_table()`

Renders a complete table with headers, rows, and borders.

```odin
draw_table :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    columns: []Table_Column,
    rows: [][]string,
    header_color: munin.Color = munin.Basic_Color.BrightCyan,
    border_color: munin.Color = munin.Basic_Color.White,
)
```

**Parameters:**
- `buf` - String builder for output
- `pos` - Top-left position of the table
- `columns` - Array of column definitions
- `rows` - 2D array of row data (each row is an array of strings)
- `header_color` - Color for header text (default: `munin.Basic_Color.BrightCyan`)
- `border_color` - Color for borders and separators (default: `munin.Basic_Color.White`)

**Features:**
- Automatic border drawing with Unicode characters
- Column headers are bold by default
- Each column can have different width and alignment
- Missing cells are handled gracefully (shown as empty)
- Full border including corners and intersections

**Border Characters Used:**
- Corners: `┌` `┐` `└` `┘`
- Lines: `─` `│`
- Intersections: `┬` `┼` `├` `┤` `┴`

**Example:**
```odin
columns := []Table_Column{
    {title = "Name", width = 20, align = .Left},
    {title = "Age", width = 5, align = .Right},
    {title = "City", width = 15, align = .Left},
}

rows := [][]string{
    {"Alice", "30", "New York"},
    {"Bob", "25", "London"},
    {"Charlie", "35", "Tokyo"},
}

draw_table(&buf, {5, 5}, columns, rows, .BrightCyan, .White)
```

## Usage Examples

### Basic Table

```odin
import "components"
import "core:strings"

buf := strings.builder_make()
defer strings.builder_destroy(&buf)

// Define columns
columns := []components.Table_Column{
    {title = "ID", width = 8, align = .Right},
    {title = "Product", width = 25, align = .Left},
    {title = "Price", width = 10, align = .Right},
    {title = "Stock", width = 8, align = .Center},
}

// Define rows
rows := [][]string{
    {"1001", "Laptop", "$999.99", "15"},
    {"1002", "Mouse", "$29.99", "150"},
    {"1003", "Keyboard", "$79.99", "45"},
    {"1004", "Monitor", "$349.99", "8"},
}

// Draw table
components.draw_table(&buf, {5, 5}, columns, rows)
```

Output:
```
┌────────┬─────────────────────────┬──────────┬────────┐
│      ID│Product                  │     Price│ Stock  │
├────────┼─────────────────────────┼──────────┼────────┤
│    1001│Laptop                   │  $999.99 │   15   │
│    1002│Mouse                    │   $29.99 │  150   │
│    1003│Keyboard                 │   $79.99 │   45   │
│    1004│Monitor                  │  $349.99 │    8   │
└────────┴─────────────────────────┴──────────┴────────┘
```

### User Table

```odin
columns := []components.Table_Column{
    {title = "Username", width = 15, align = .Left},
    {title = "Email", width = 30, align = .Left},
    {title = "Status", width = 10, align = .Center},
    {title = "Role", width = 12, align = .Left},
}

rows := [][]string{
    {"admin", "admin@example.com", "Active", "Administrator"},
    {"john_doe", "john@example.com", "Active", "User"},
    {"jane_smith", "jane@example.com", "Inactive", "Moderator"},
}

components.draw_table(&buf, {5, 5}, columns, rows, .BrightYellow, .BrightBlue)
```

### Alignment Examples

```odin
// Table demonstrating different alignments
columns := []components.Table_Column{
    {title = "Left", width = 15, align = .Left},
    {title = "Center", width = 15, align = .Center},
    {title = "Right", width = 15, align = .Right},
}

rows := [][]string{
    {"Left aligned", "Centered", "Right aligned"},
    {"Text", "Text", "Text"},
    {"ABC", "ABC", "ABC"},
}

components.draw_table(&buf, {5, 5}, columns, rows)
```

Output:
```
┌───────────────┬───────────────┬───────────────┐
│Left           │    Center     │          Right│
├───────────────┼───────────────┼───────────────┤
│Left aligned   │   Centered    │  Right aligned│
│Text           │      Text     │           Text│
│ABC            │      ABC      │            ABC│
└───────────────┴───────────────┴───────────────┘
```

### Server Status Table

```odin
Server :: struct {
    name: string,
    ip: string,
    status: string,
    uptime: string,
    load: string,
}

draw_server_table :: proc(servers: []Server, buf: ^strings.Builder) {
    columns := []components.Table_Column{
        {title = "Server", width = 20, align = .Left},
        {title = "IP Address", width = 16, align = .Left},
        {title = "Status", width = 10, align = .Center},
        {title = "Uptime", width = 12, align = .Right},
        {title = "Load", width = 8, align = .Right},
    }

    // Convert servers to string rows
    rows := make([][]string, len(servers))
    defer delete(rows)

    for server, i in servers {
        rows[i] = []string{
            server.name,
            server.ip,
            server.status,
            server.uptime,
            server.load,
        }
    }

    components.draw_table(&buf, {5, 5}, columns, rows, .BrightGreen, .White)
}

// Usage
servers := []Server{
    {"web-01", "192.168.1.10", "Online", "45d 3h", "0.45"},
    {"web-02", "192.168.1.11", "Online", "30d 12h", "0.67"},
    {"db-01", "192.168.1.20", "Offline", "0d 0h", "0.00"},
}

draw_server_table(servers, &buf)
```

### Financial Data Table

```odin
columns := []components.Table_Column{
    {title = "Date", width = 12, align = .Left},
    {title = "Description", width = 30, align = .Left},
    {title = "Amount", width = 12, align = .Right},
    {title = "Balance", width = 12, align = .Right},
}

rows := [][]string{
    {"2025-11-01", "Opening Balance", "", "$10,000.00"},
    {"2025-11-05", "Salary Deposit", "+$5,000.00", "$15,000.00"},
    {"2025-11-10", "Rent Payment", "-$1,500.00", "$13,500.00"},
    {"2025-11-15", "Groceries", "-$250.50", "$13,249.50"},
    {"2025-11-20", "Freelance Income", "+$2,500.00", "$15,749.50"},
}

components.draw_table(&buf, {5, 5}, columns, rows, .BrightCyan, .White)
```

### Empty and Missing Cell Handling

```odin
// Table with missing cells
columns := []components.Table_Column{
    {title = "Col A", width = 10, align = .Left},
    {title = "Col B", width = 10, align = .Left},
    {title = "Col C", width = 10, align = .Left},
}

rows := [][]string{
    {"A1", "B1", "C1"},      // Complete row
    {"A2", "B2"},            // Missing C2
    {"A3"},                  // Missing B3 and C3
    {},                      // Empty row
}

components.draw_table(&buf, {5, 5}, columns, rows)
```

Output:
```
┌──────────┬──────────┬──────────┐
│Col A     │Col B     │Col C     │
├──────────┼──────────┼──────────┤
│A1        │B1        │C1        │
│A2        │B2        │          │
│A3        │          │          │
│          │          │          │
└──────────┴──────────┴──────────┘
```

### Dynamic Column Widths

```odin
calculate_column_width :: proc(data: []string, min_width: int) -> int {
    max_len := min_width
    for item in data {
        max_len = max(max_len, len(item))
    }
    return max_len + 2  // Add padding
}

create_auto_sized_table :: proc(
    headers: []string,
    rows: [][]string,
    buf: ^strings.Builder,
) {
    columns := make([]components.Table_Column, len(headers))
    defer delete(columns)

    // Calculate widths based on content
    for header, i in headers {
        // Get all values in this column
        column_data := make([dynamic]string)
        defer delete(column_data)

        append(&column_data, header)
        for row in rows {
            if i < len(row) {
                append(&column_data, row[i])
            }
        }

        width := calculate_column_width(column_data[:], 10)
        columns[i] = {
            title = header,
            width = width,
            align = .Left,
        }
    }

    components.draw_table(&buf, {5, 5}, columns, rows)
}
```

### Scrollable Table (With Pagination)

```odin
Table_View :: struct {
    columns: []components.Table_Column,
    all_rows: [][]string,
    current_page: int,
    rows_per_page: int,
}

draw_paginated_table :: proc(view: ^Table_View, buf: ^strings.Builder) {
    // Get current page rows
    visible_rows := components.get_page_slice(
        view.all_rows,
        view.current_page,
        view.rows_per_page,
    )

    // Draw table
    components.draw_table(&buf, {5, 5}, view.columns, visible_rows)

    // Draw pagination below
    total_pages := components.calculate_pages(
        len(view.all_rows),
        view.rows_per_page,
    )

    components.draw_pagination(
        buf,
        {5, 5 + len(visible_rows) + 4},  // Below table
        view.current_page,
        total_pages,
        .Numbers,
    )
}
```

### Sortable Table (Conceptual)

```odin
Sort_Order :: enum {
    None,
    Ascending,
    Descending,
}

Table_State :: struct {
    data: [][]string,
    sort_column: int,
    sort_order: Sort_Order,
}

sort_table_data :: proc(state: ^Table_State, column: int) {
    // Toggle sort order
    if state.sort_column == column {
        switch state.sort_order {
        case .None, .Descending:
            state.sort_order = .Ascending
        case .Ascending:
            state.sort_order = .Descending
        }
    } else {
        state.sort_column = column
        state.sort_order = .Ascending
    }

    // Sort data based on column and order
    // ... sorting logic ...
}

draw_sortable_table :: proc(state: ^Table_State, buf: ^strings.Builder) {
    // Modify column titles to show sort indicators
    columns := make([]components.Table_Column, 3)
    defer delete(columns)

    // Add sort indicator to sorted column
    for i in 0..<len(columns) {
        suffix := ""
        if state.sort_column == i {
            suffix = state.sort_order == .Ascending ? " ▲" : " ▼"
        }
        columns[i].title = fmt.tprintf("%s%s", base_titles[i], suffix)
    }

    components.draw_table(&buf, {5, 5}, columns, state.data)
}
```

## Visual Reference

### Complete Table Structure

```
┌────────┬─────────────┬──────────┐  ← Top border
│Header 1│  Header 2   │ Header 3 │  ← Header row (bold)
├────────┼─────────────┼──────────┤  ← Header separator
│Data 1  │   Data 2    │   Data 3 │  ← Data rows
│Data 4  │   Data 5    │   Data 6 │
└────────┴─────────────┴──────────┘  ← Bottom border
```

### Border Character Layout

```
Corner: ┌  ┐  └  ┘
T-junctions: ┬  ┴  ├  ┤
Cross: ┼
Lines: ─ (horizontal)  │ (vertical)
```

## Best Practices

1. **Column widths** - Calculate based on content or use fixed widths for consistency
2. **Alignment** - Use right-align for numbers, left for text, center for status
3. **Empty handling** - Gracefully handle missing data in rows
4. **Width constraints** - Ensure total width fits within terminal dimensions
5. **Header clarity** - Use descriptive, concise column headers
6. **Color coding** - Use colors to highlight headers and important data
7. **Row count** - For large datasets, implement pagination or scrolling

## Common Patterns

### CSV to Table

```odin
csv_to_table :: proc(csv_lines: []string) -> ([]components.Table_Column, [][]string) {
    if len(csv_lines) == 0 do return nil, nil

    // Parse header
    headers := strings.split(csv_lines[0], ",")

    // Create columns
    columns := make([]components.Table_Column, len(headers))
    for header, i in headers {
        columns[i] = {
            title = strings.trim_space(header),
            width = 20,
            align = .Left,
        }
    }

    // Parse rows
    rows := make([][]string, len(csv_lines) - 1)
    for line, i in csv_lines[1:] {
        rows[i] = strings.split(line, ",")
    }

    return columns, rows
}
```

## Integration

Requires:
- `munin` package for colors and cursor positioning
- `core:strings` for string building and manipulation
- `core:slice` for row operations

## Notes

- Column headers are automatically rendered in bold
- Text longer than column width is truncated
- Padding is handled automatically by alignment
- Unicode box-drawing characters require UTF-8 terminal support
- Total table width = sum of column widths + borders (1 character per column + 1)
- Table height = number of rows + 4 (top border, header, separator, bottom border)
- Empty columns are rendered as blank spaces
