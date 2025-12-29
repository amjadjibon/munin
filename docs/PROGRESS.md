# Progress Bar Component

The Progress Bar component provides visual progress indicators with multiple styles for both horizontal and vertical orientations.

## Overview

Located in `munin/components/progress.odin`, this component offers flexible progress visualization with various fill styles, percentage display, and border options.

## Progress Styles

### `Progress_Style` enum

- **Blocks** - Solid blocks: `████░░░░`
- **Bars** - Vertical bars: `||||    `
- **Dots** - Filled/empty dots: `●●●○○○○`
- **Arrow** - Arrow with equals: `====>---`
- **Gradient** - Gradient blocks: `▓▓▒▒░░░`

## Functions

### `draw_progress_bar()`

Renders a horizontal progress bar with customizable styling.

```odin
draw_progress_bar :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    width: int,
    progress: int,              // 0-100
    style: Progress_Style = .Blocks,
    filled_color: munin.Color = munin.Basic_Color.BrightGreen,
    empty_color: munin.Color = munin.Basic_Color.White,
    show_percent: bool = true,
)
```

**Parameters:**
- `buf` - String builder for output
- `pos` - Position to draw the progress bar
- `width` - Total width of the bar in characters
- `progress` - Progress value from 0 to 100
- `style` - Visual style (default: `.Blocks`)
- `filled_color` - Color for completed portion (default: `munin.Basic_Color.BrightGreen`)
- `empty_color` - Color for remaining portion (default: `munin.Basic_Color.White`)
- `show_percent` - Display percentage text after bar (default: `true`)

**Features:**
- Progress is automatically clamped to 0-100 range
- Percentage appears 2 characters after the bar
- Different character sets for each style
- Smooth visual representation

**Example:**
```odin
draw_progress_bar(&buf, {10, 10}, 40, 65, .Blocks, .BrightGreen, .White, true)
```

---

### `draw_progress_bar_vertical()`

Renders a vertical progress bar (fills from bottom to top).

```odin
draw_progress_bar_vertical :: proc(
    buf: ^strings.Builder,
    x, y, height: int,
    progress: int,              // 0-100
    filled_color: munin.Color = munin.Basic_Color.BrightGreen,
    empty_color: munin.Color = munin.Basic_Color.White,
)
```

**Parameters:**
- `buf` - String builder for output
- `x` - X position (single column)
- `y` - Y position (top of bar)
- `height` - Total height of the bar in characters
- `progress` - Progress value from 0 to 100
- `filled_color` - Color for completed portion
- `empty_color` - Color for remaining portion

**Features:**
- Fills from bottom upward
- Uses block characters (`█` filled, `░` empty)
- Useful for vertical space utilization

**Example:**
```odin
draw_progress_bar_vertical(&buf, 10, 5, 20, 75, .BrightGreen, .White)
```

---

### `draw_progress_bar_boxed()`

Renders a progress bar with a border and optional label.

```odin
draw_progress_bar_boxed :: proc(
    buf: ^strings.Builder,
    x, y, width: int,
    progress: int,
    label: string = "",
    filled_color: munin.Color = munin.Basic_Color.BrightGreen,
    empty_color: munin.Color = munin.Basic_Color.White,
)
```

**Parameters:**
- `buf` - String builder for output
- `x` - X position
- `y` - Y position
- `width` - Total width including borders
- `progress` - Progress value from 0 to 100
- `label` - Optional label displayed above bar
- `filled_color` - Color for completed portion
- `empty_color` - Color for remaining portion

**Features:**
- Adds `[` and `]` borders around the bar
- Label appears above the bar in bright yellow
- Automatically shows percentage

**Example:**
```odin
draw_progress_bar_boxed(&buf, 10, 10, 40, 80, "Download Progress", .BrightCyan, .White)
```

## Usage Examples

### Basic Progress Bar

```odin
import "munin/components"
import "core:strings"

buf := strings.builder_make()
defer strings.builder_destroy(&buf)

// Draw a 50% progress bar
components.draw_progress_bar(
    &buf,
    {10, 10},
    40,        // Width
    50,        // 50% complete
    .Blocks,
)
```
Output: `████████████████████░░░░░░░░░░░░░░░░░░░░  50%`

### Different Styles

```odin
// Blocks style (default)
components.draw_progress_bar(&buf, {5, 5}, 30, 70, .Blocks, .BrightGreen, .White, true)
// Output: █████████████████████░░░░░░░░░  70%

// Bars style
components.draw_progress_bar(&buf, {5, 7}, 30, 70, .Bars, .BrightBlue, .White, true)
// Output: |||||||||||||||||||||||         70%

// Dots style
components.draw_progress_bar(&buf, {5, 9}, 30, 70, .Dots, .BrightYellow, .White, true)
// Output: ●●●●●●●●●●●●●●●●●●●●●○○○○○○○○  70%

// Arrow style
components.draw_progress_bar(&buf, {5, 11}, 30, 70, .Arrow, .BrightCyan, .White, true)
// Output: ====================>---------  70%

// Gradient style
components.draw_progress_bar(&buf, {5, 13}, 30, 70, .Gradient, .BrightMagenta, .White, true)
// Output: ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░  70%
```

### Vertical Progress Bar

```odin
// Draw a vertical bar (e.g., volume indicator)
components.draw_progress_bar_vertical(
    &buf,
    5,         // X position
    5,         // Y position (top)
    20,        // Height
    80,        // 80% filled
    .BrightGreen,
    .BrightBlue,
)
```
Output (vertical, bottom to top):
```
░
░
░
░
█
█
█
█
█
█
█
█
█
█
█
█
█
█
█
█
```

### Progress Bar with Label

```odin
components.draw_progress_bar_boxed(
    &buf,
    10, 10,
    50,          // Width
    35,          // Progress
    "Installing packages...",
    .BrightCyan,
    .White,
)
```
Output:
```
Installing packages...
[█████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░  35%]
```

### Multi-Progress Display

```odin
Task :: struct {
    name: string,
    progress: int,
    color: munin.Color,
}

draw_task_progress :: proc(tasks: []Task, buf: ^strings.Builder, start_y: int) {
    for task, i in tasks {
        y := start_y + (i * 2)

        components.draw_progress_bar_boxed(
            buf,
            5, y,
            60,
            task.progress,
            task.name,
            task.color,
            .White,
        )
    }
}

// Usage
tasks := []Task{
    {"Compiling source files", 100, .BrightGreen},
    {"Running tests", 65, .BrightYellow},
    {"Generating documentation", 30, .BrightBlue},
    {"Building package", 0, .BrightBlue},
}

draw_task_progress(tasks, &buf, 5)
```

### File Download Progress

```odin
Download_State :: struct {
    filename: string,
    bytes_downloaded: int,
    total_bytes: int,
    speed: f32,  // KB/s
}

draw_download :: proc(state: ^Download_State, buf: ^strings.Builder) {
    progress := int((f32(state.bytes_downloaded) / f32(state.total_bytes)) * 100)

    // Draw filename
    munin.print_at(buf, {5, 5}, state.filename, .BrightCyan)

    // Draw progress bar
    components.draw_progress_bar(
        buf,
        {5, 6},
        60,
        progress,
        .Blocks,
        .BrightGreen,
        .White,
        true,
    )

    // Draw stats
    mb_downloaded := f32(state.bytes_downloaded) / 1024 / 1024
    mb_total := f32(state.total_bytes) / 1024 / 1024
    stats := fmt.tprintf("%.1f MB / %.1f MB @ %.1f KB/s",
        mb_downloaded, mb_total, state.speed)
    munin.print_at(buf, {5, 7}, stats, .BrightBlue)
}
```

### Dynamic Color Based on Progress

```odin
get_progress_color :: proc(progress: int) -> munin.Color {
    if progress < 30 {
        return .BrightRed
    } else if progress < 70 {
        return .BrightYellow
    } else {
        return .BrightGreen
    }
}

draw_adaptive_progress :: proc(buf: ^strings.Builder, progress: int) {
    color := get_progress_color(progress)
    components.draw_progress_bar(
        buf, {10, 10}, 40, progress,
        .Blocks, color, .White, true,
    )
}
```

### Loading Animation with Progress

```odin
Loading_State :: struct {
    progress: int,
    frame: int,
    message: string,
}

draw_loading :: proc(state: ^Loading_State, buf: ^strings.Builder) {
    // Draw spinner
    components.draw_spinner(buf, {5, 5}, state.frame, .Dots, .BrightCyan, state.message)

    // Draw progress bar
    components.draw_progress_bar(
        buf,
        {5, 7},
        50,
        state.progress,
        .Blocks,
        .BrightCyan,
        .White,
        true,
    )
}
```

### Battery/Volume Indicator

```odin
draw_battery :: proc(level: int, buf: ^strings.Builder) {
    color := munin.Color.BrightGreen
    if level < 20 {
        color = .BrightRed
    } else if level < 50 {
        color = .BrightYellow
    }

    munin.print_at(buf, {5, 5}, "Battery:", .White)
    components.draw_progress_bar(
        buf, {14, 5}, 20, level,
        .Blocks, color, .White, true,
    )
}
```

## Visual Reference

### All Styles at 60%

```
Blocks:   ████████████████████████░░░░░░░░░░░░░░░░  60%
Bars:     ||||||||||||||||||||||||                  60%
Dots:     ●●●●●●●●●●●●●●●●●●●●●●●●○○○○○○○○○○○○○○○○  60%
Arrow:    ========================>---------------  60%
Gradient: ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░  60%
```

### Boxed Progress

```
Download Progress
[████████████░░░░░░░░░░░░░░░░░░░░  30%]
```

### Vertical Progress (80%)

```
░
░
░
░
█
█
█
█
█
█
```

## Best Practices

1. **Progress values** - Always clamp input to 0-100 range
2. **Width sizing** - Use minimum width of 20 for readability
3. **Color selection** - Use green for success, yellow for warning, red for critical
4. **Style choice** - Use `.Blocks` for general purpose, `.Arrow` for downloads
5. **Percentage display** - Show percentage for precision, hide for space constraints
6. **Update frequency** - Update at least every 100ms for smooth animation
7. **Vertical bars** - Use height of at least 10 for visibility

## Common Patterns

### Progress Update Loop

```odin
update_progress :: proc(state: ^Progress_State, delta: f32) {
    state.progress += delta
    state.progress = clamp(state.progress, 0, 100)

    // Redraw
    buf := strings.builder_make()
    defer strings.builder_destroy(&buf)

    components.draw_progress_bar(
        &buf, {10, 10}, 40,
        int(state.progress),
        .Blocks, .BrightGreen, .White, true,
    )

    // Flush to screen
    munin.flush(&buf)
}
```

### Progress with Time Remaining

```odin
draw_progress_with_eta :: proc(
    progress: int,
    elapsed: time.Duration,
    buf: ^strings.Builder,
) {
    components.draw_progress_bar(
        buf, {5, 5}, 50, progress,
        .Blocks, .BrightGreen, .White, true,
    )

    if progress > 0 {
        total_time := elapsed * 100 / time.Duration(progress)
        remaining := total_time - elapsed
        eta := format_duration(remaining)
        munin.print_at(buf, {5, 6}, fmt.tprintf("ETA: %s", eta), .BrightBlue)
    }
}
```

## Integration

Requires:
- `munin` package for colors and cursor positioning
- `core:strings` for string building

## Notes

- Progress is calculated as `(progress * width) / 100`
- All progress values are clamped to 0-100 range internally
- Percentage text adds approximately 5 characters to the right
- Vertical bars use single-column width
- Different styles use different Unicode characters - ensure terminal supports them
- Empty portions use lighter/outline characters for visual distinction
