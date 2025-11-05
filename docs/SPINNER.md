# Spinner Component

The Spinner component provides animated loading indicators with multiple visual styles and directional control.

## Overview

Located in `components/spinner.odin`, this component offers various animated spinner styles for indicating background processes, loading states, and ongoing operations.

## Spinner Styles

### `Spinner_Style` enum

- **Dots** - Braille dot patterns: `⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧` (8 frames)
- **Line** - Rotating line: `- \ | /` (4 frames)
- **Arrow** - Circular arrows: `← ↖ ↑ ↗ → ↘ ↓ ↙` (8 frames)
- **Circle** - Rotating circle segments: `◐ ◓ ◑ ◒` (4 frames)
- **Box** - Rotating box segments: `◰ ◳ ◲ ◱` (4 frames)
- **Star** - Pulsing star: `✶ ✸ ✹ ✺ ✹ ✸` (6 frames)
- **Moon** - Moon phases: `🌑 🌒 🌓 🌔 🌕 🌖 🌗 🌘` (8 frames)
- **Clock** - Clock face hours: `🕐 🕑 🕒 ... 🕛` (12 frames)

### `Spinner_Direction` enum

- **Forward** - Normal frame progression
- **Reverse** - Reversed frame progression

## Functions

### `draw_spinner()`

Renders an animated spinner frame.

```odin
draw_spinner :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    frame: int,
    style: Spinner_Style = .Dots,
    color: munin.Color = .BrightCyan,
    label: string = "",
    direction: Spinner_Direction = .Forward,
)
```

**Parameters:**
- `buf` - String builder for output
- `pos` - Position to draw the spinner
- `frame` - Current frame number (typically incremented each render)
- `style` - Visual style (default: `.Dots`)
- `color` - Spinner color (default: `.BrightCyan`)
- `label` - Optional text label to the right of spinner
- `direction` - Rotation direction (default: `.Forward`)

**Features:**
- Frame number automatically wraps based on style frame count
- Label appears 2 characters to the right of spinner
- Direction controls animation flow

**Example:**
```odin
draw_spinner(&buf, {10, 10}, frame_counter, .Dots, .BrightCyan, "Loading...")
```

---

### `get_spinner_frame_count()`

Returns the number of frames for a given spinner style.

```odin
get_spinner_frame_count :: proc(style: Spinner_Style) -> int
```

**Parameters:**
- `style` - Spinner style to query

**Returns:** Number of frames in the animation

**Usage:**
Useful for calculating animation loops or timing.

**Example:**
```odin
frame_count := get_spinner_frame_count(.Dots)  // Returns 8
```

## Usage Examples

### Basic Spinner

```odin
import "components"
import "core:strings"

buf := strings.builder_make()
defer strings.builder_destroy(&buf)

frame := 0

// In your render loop:
components.draw_spinner(
    &buf,
    {10, 10},
    frame,
    .Dots,
    .BrightCyan,
    "Processing...",
)

frame += 1  // Increment each frame
```

### All Spinner Styles

```odin
Demo_Spinner :: struct {
    style: components.Spinner_Style,
    label: string,
    color: munin.Color,
}

draw_spinner_showcase :: proc(frame: int, buf: ^strings.Builder) {
    spinners := []Demo_Spinner{
        {.Dots, "Dots style", .BrightCyan},
        {.Line, "Line style", .BrightGreen},
        {.Arrow, "Arrow style", .BrightYellow},
        {.Circle, "Circle style", .BrightMagenta},
        {.Box, "Box style", .BrightBlue},
        {.Star, "Star style", .BrightRed},
        {.Moon, "Moon style", .Yellow},
        {.Clock, "Clock style", .White},
    }

    for spinner, i in spinners {
        y := 5 + (i * 2)
        components.draw_spinner(
            buf,
            {5, y},
            frame,
            spinner.style,
            spinner.color,
            spinner.label,
        )
    }
}
```

### Loading Screen

```odin
Loading_Screen :: struct {
    frame: int,
    message: string,
    progress: int,
}

draw_loading_screen :: proc(state: ^Loading_Screen, buf: ^strings.Builder) {
    screen_width := 80
    screen_height := 24

    // Center the spinner
    center_x := screen_width / 2 - 5
    center_y := screen_height / 2

    // Draw spinner
    components.draw_spinner(
        buf,
        {center_x, center_y},
        state.frame,
        .Dots,
        .BrightCyan,
        state.message,
    )

    // Draw progress bar below
    components.draw_progress_bar(
        buf,
        {center_x - 10, center_y + 2},
        40,
        state.progress,
        .Blocks,
    )

    state.frame += 1
}
```

### Spinner with Status List

```odin
Task_Status :: enum {
    Pending,
    Running,
    Complete,
    Failed,
}

Task :: struct {
    name: string,
    status: Task_Status,
}

draw_task_list :: proc(tasks: []Task, frame: int, buf: ^strings.Builder) {
    for task, i in tasks {
        y := 5 + i

        switch task.status {
        case .Pending:
            munin.print_at(buf, {5, y}, "○", .BrightBlue)
            munin.print_at(buf, {7, y}, task.name, .BrightBlue)

        case .Running:
            components.draw_spinner(
                buf, {5, y}, frame,
                .Dots, .BrightYellow,
            )
            munin.print_at(buf, {7, y}, task.name, .White)

        case .Complete:
            munin.print_at(buf, {5, y}, "✓", .BrightGreen)
            munin.print_at(buf, {7, y}, task.name, .BrightGreen)

        case .Failed:
            munin.print_at(buf, {5, y}, "✗", .BrightRed)
            munin.print_at(buf, {7, y}, task.name, .BrightRed)
        }
    }
}
```

### Multi-Spinner (Different Speeds)

```odin
Animated_Spinner :: struct {
    style: components.Spinner_Style,
    speed: int,  // Update every N frames
    label: string,
    counter: int,
}

update_and_draw_spinners :: proc(
    spinners: []^Animated_Spinner,
    global_frame: int,
    buf: ^strings.Builder,
) {
    for spinner, i in spinners {
        y := 5 + (i * 2)

        // Update spinner counter based on speed
        if global_frame % spinner.speed == 0 {
            spinner.counter += 1
        }

        components.draw_spinner(
            buf, {5, y},
            spinner.counter,
            spinner.style,
            .BrightCyan,
            spinner.label,
        )
    }
}

// Usage
spinners := []^Animated_Spinner{
    &{.Dots, 1, "Fast", 0},      // Updates every frame
    &{.Line, 3, "Medium", 0},    // Updates every 3 frames
    &{.Circle, 5, "Slow", 0},    // Updates every 5 frames
}
```

### Reverse Direction Spinner

```odin
components.draw_spinner(
    &buf,
    {10, 10},
    frame,
    .Arrow,
    .BrightYellow,
    "Unwinding...",
    .Reverse,  // Spins in reverse
)
```

### Download Manager with Spinners

```odin
Download :: struct {
    filename: string,
    active: bool,
}

draw_downloads :: proc(downloads: []Download, frame: int, buf: ^strings.Builder) {
    for download, i in downloads {
        y := 5 + i

        if download.active {
            components.draw_spinner(
                buf, {5, y}, frame,
                .Dots, .BrightGreen,
                download.filename,
            )
        } else {
            munin.print_at(buf, {5, y}, "✓", .BrightGreen)
            munin.print_at(buf, {7, y}, download.filename, .White)
        }
    }
}
```

### Timed Spinner (Auto-Stop)

```odin
Timed_Spinner :: struct {
    start_time: time.Time,
    duration: time.Duration,
    style: components.Spinner_Style,
    frame: int,
}

draw_timed_spinner :: proc(state: ^Timed_Spinner, buf: ^strings.Builder) -> bool {
    elapsed := time.since(state.start_time)

    if elapsed < state.duration {
        components.draw_spinner(
            buf, {10, 10},
            state.frame,
            state.style,
            .BrightCyan,
            "Please wait...",
        )
        state.frame += 1
        return true  // Still running
    }

    munin.print_at(buf, {10, 10}, "✓ Complete!", .BrightGreen)
    return false  // Finished
}
```

### Spinner Animation Loop

```odin
Spinner_State :: struct {
    frame: int,
    last_update: time.Time,
    update_interval: time.Duration,
}

make_spinner_state :: proc(fps: int) -> Spinner_State {
    return Spinner_State{
        frame = 0,
        last_update = time.now(),
        update_interval = time.Second / time.Duration(fps),
    }
}

update_spinner :: proc(state: ^Spinner_State) -> bool {
    now := time.now()
    elapsed := time.diff(state.last_update, now)

    if elapsed >= state.update_interval {
        state.frame += 1
        state.last_update = now
        return true  // Frame updated
    }

    return false  // No update needed
}

// Usage in main loop
spinner := make_spinner_state(10)  // 10 FPS

for {
    if update_spinner(&spinner) {
        buf := strings.builder_make()
        defer strings.builder_destroy(&buf)

        components.draw_spinner(
            &buf, {10, 10},
            spinner.frame,
            .Dots,
            .BrightCyan,
            "Loading...",
        )

        munin.flush(&buf)
    }

    time.sleep(10 * time.Millisecond)
}
```

## Visual Reference

### All Styles (Single Frame)

```
⠋ Dots
| Line
→ Arrow
◐ Circle
◰ Box
✶ Star
🌑 Moon
🕐 Clock
```

### Animation Sequences

**Dots (8 frames):**
```
⠋ → ⠙ → ⠹ → ⠸ → ⠼ → ⠴ → ⠦ → ⠧ → (repeat)
```

**Line (4 frames):**
```
- → \ → | → / → (repeat)
```

**Arrow (8 frames):**
```
← → ↖ → ↑ → ↗ → → → ↘ → ↓ → ↙ → (repeat)
```

**Circle (4 frames):**
```
◐ → ◓ → ◑ → ◒ → (repeat)
```

## Best Practices

1. **Update frequency** - Update spinners at 8-15 FPS for smooth animation
2. **Style selection** - Use `.Dots` for minimal, `.Clock` for fun, `.Line` for compatibility
3. **Color coding** - Blue/cyan for loading, yellow for processing, green for completion
4. **Label placement** - Keep labels concise (under 30 characters)
5. **Frame management** - Increment frame counter on each render or timer
6. **Direction** - Use `.Reverse` to indicate backward processes (undo, rewind)
7. **Unicode support** - `.Line` is ASCII-safe, other styles require UTF-8 terminal

## Common Patterns

### Spinner Factory

```odin
create_loading_spinner :: proc() -> Spinner_Config {
    return {
        style = .Dots,
        color = .BrightCyan,
        label = "Loading...",
        frame = 0,
    }
}

create_processing_spinner :: proc() -> Spinner_Config {
    return {
        style = .Circle,
        color = .BrightYellow,
        label = "Processing...",
        frame = 0,
    }
}

create_saving_spinner :: proc() -> Spinner_Config {
    return {
        style = .Arrow,
        color = .BrightGreen,
        label = "Saving...",
        frame = 0,
    }
}
```

### Spinner with Timeout

```odin
draw_spinner_with_timeout :: proc(
    frame: int,
    timeout: time.Duration,
    elapsed: time.Duration,
    buf: ^strings.Builder,
) {
    if elapsed > timeout {
        munin.print_at(buf, {10, 10}, "✗ Timeout!", .BrightRed)
        return
    }

    remaining := timeout - elapsed
    label := fmt.tprintf("Waiting... %ds", int(time.duration_seconds(remaining)))

    components.draw_spinner(
        buf, {10, 10}, frame,
        .Clock, .BrightYellow,
        label,
    )
}
```

## Integration

Requires:
- `munin` package for colors and cursor positioning
- `core:strings` for string building

## Notes

- Frame numbers automatically wrap using modulo operation
- Different styles have different frame counts (4, 6, 8, or 12)
- Unicode emoji styles (Moon, Clock) may not render on all terminals
- Spinner width is always 1 character (plus label)
- Direction affects frame calculation but not animation speed
- Labels are optional but improve user experience
- Spinners are best updated at consistent intervals (timer-based or frame-based)
