# Timer Component

The Timer component provides countdown timer visualization with multiple display modes, progress indicators, and preset buttons.

## Overview

Located in `components/timer.odin`, this component offers comprehensive countdown timer functionality with state management and various visual representations.

## Timer State

### `Timer_State` enum

Timer operational states:

- **Ready** - Timer is ready to start
- **Running** - Timer is actively counting down
- **Paused** - Timer is temporarily paused
- **Finished** - Timer has reached zero

## Functions

### `draw_timer()`

Renders a countdown timer with state indicator.

```odin
draw_timer :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    remaining: time.Duration,
    state: Timer_State,
    show_milliseconds: bool = false,
    label_color: munin.Color = .BrightYellow,
    time_color: munin.Color = .BrightGreen,
)
```

**Parameters:**
- `buf` - String builder for output
- `pos` - Position to draw the timer
- `remaining` - Time remaining (can be negative for overtime)
- `state` - Current timer state
- `show_milliseconds` - Include milliseconds in display (default: `false`)
- `label_color` - Color for labels (default: `.BrightYellow`)
- `time_color` - Color for time display (default: `.BrightGreen`)

**Features:**
- Formats time as `HH:MM:SS` or `HH:MM:SS.mmm`
- Color changes based on remaining time:
  - Green: Normal (> 10 seconds)
  - Yellow: Warning (< 10 seconds)
  - Red: Finished (≤ 0 seconds)
- Shows state indicator with icon and text
- Time display is bold

**State Indicators:**
- Ready: `⏸ Ready` (Blue)
- Running: `▶ Running` (Green)
- Paused: `⏸ Paused` (Yellow)
- Finished: `✓ Finished` (Red)

**Example:**
```odin
draw_timer(&buf, {10, 10}, 5 * time.Minute + 30 * time.Second, .Running)
```

---

### `draw_timer_with_progress()`

Renders a timer with a progress bar showing elapsed time.

```odin
draw_timer_with_progress :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    remaining: time.Duration,
    total: time.Duration,
    state: Timer_State,
    width: int = 40,
)
```

**Parameters:**
- `buf` - String builder for output
- `pos` - Position to draw
- `remaining` - Time remaining
- `total` - Total timer duration (for progress calculation)
- `state` - Current timer state
- `width` - Progress bar width (default: 40)

**Features:**
- Shows countdown timer at top
- Progress bar appears 2 lines below timer
- Progress indicates elapsed time (0% to 100%)
- Useful for visualizing timer completion

**Example:**
```odin
total := 10 * time.Minute
remaining := 7 * time.Minute
draw_timer_with_progress(&buf, {10, 10}, remaining, total, .Running, 50)
```

---

### `draw_timer_boxed()`

Renders a timer inside a styled box with controls hint.

```odin
draw_timer_boxed :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    width: int,
    remaining: time.Duration,
    total: time.Duration,
    state: Timer_State,
    title: string = "Timer",
)
```

**Parameters:**
- `buf` - String builder for output
- `pos` - Top-left position of the box
- `width` - Box width
- `remaining` - Time remaining
- `total` - Total timer duration
- `state` - Current timer state
- `title` - Box title (default: `"Timer"`)

**Features:**
- Draws titled box around timer
- Includes timer with progress bar
- Shows control hints at bottom: `[Space] Start/Pause  [r] Reset`
- Height is fixed at 8 lines

**Example:**
```odin
draw_timer_boxed(&buf, {10, 5}, 60, remaining, total, .Running, "Pomodoro Timer")
```

---

### `draw_timer_presets()`

Renders preset timer buttons for quick selection.

```odin
draw_timer_presets :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    presets: []int,  // Duration in seconds
    selected: int = -1,
)
```

**Parameters:**
- `buf` - String builder for output
- `pos` - Starting position
- `presets` - Array of preset durations in seconds
- `selected` - Currently selected preset index (-1 for none)

**Features:**
- Shows "Quick Timers:" label
- Displays preset buttons horizontally
- Selected preset has highlighted background
- Formats as minutes or seconds based on duration
- Buttons appear 2 lines below label
- Each button is spaced 12 characters apart

**Button Format:**
- Minutes: ` 5m ` (if duration ≥ 60 seconds)
- Seconds: ` 30s ` (if duration < 60 seconds)

**Example:**
```odin
presets := []int{30, 60, 300, 600, 900}  // 30s, 1m, 5m, 10m, 15m
draw_timer_presets(&buf, {5, 20}, presets, 2)  // 5m selected
```

## Usage Examples

### Basic Countdown Timer

```odin
import "components"
import "core:strings"
import "core:time"

buf := strings.builder_make()
defer strings.builder_destroy(&buf)

remaining := 5 * time.Minute + 30 * time.Second

components.draw_timer(
    &buf,
    {10, 10},
    remaining,
    .Running,
    false,  // Don't show milliseconds
    .BrightYellow,
    .BrightGreen,
)
```

Output: `00:05:30 ▶ Running`

### Timer with Milliseconds

```odin
remaining := 10 * time.Second + 500 * time.Millisecond

components.draw_timer(
    &buf,
    {10, 10},
    remaining,
    .Running,
    true,  // Show milliseconds
)
```

Output: `00:00:10.500 ▶ Running`

### Timer with Progress Bar

```odin
total := 10 * time.Minute
remaining := 3 * time.Minute

components.draw_timer_with_progress(
    &buf,
    {10, 10},
    remaining,
    total,
    .Running,
    50,
)
```

Output:
```
00:03:00 ▶ Running

███████████████████████████████████░░░░░░░░░░░░░░  70%
```

### Full Timer Interface

```odin
Timer :: struct {
    total: time.Duration,
    remaining: time.Duration,
    state: components.Timer_State,
    presets: []int,
    selected_preset: int,
}

draw_timer_ui :: proc(timer: ^Timer, buf: ^strings.Builder) {
    // Draw boxed timer
    components.draw_timer_boxed(
        buf,
        {10, 5},
        60,
        timer.remaining,
        timer.total,
        timer.state,
        "Countdown Timer",
    )

    // Draw preset buttons
    components.draw_timer_presets(
        buf,
        {10, 15},
        timer.presets,
        timer.selected_preset,
    )
}

// Usage
timer := Timer{
    total = 5 * time.Minute,
    remaining = 5 * time.Minute,
    state = .Ready,
    presets = []int{30, 60, 300, 600, 900},
    selected_preset = -1,
}

draw_timer_ui(&timer, &buf)
```

### Pomodoro Timer

```odin
Pomodoro_State :: enum {
    Work,
    Short_Break,
    Long_Break,
}

Pomodoro :: struct {
    state: Pomodoro_State,
    remaining: time.Duration,
    timer_state: components.Timer_State,
}

draw_pomodoro :: proc(pomodoro: ^Pomodoro, buf: ^strings.Builder) {
    title := ""
    total := time.Duration(0)

    switch pomodoro.state {
    case .Work:
        title = "Work Time"
        total = 25 * time.Minute
    case .Short_Break:
        title = "Short Break"
        total = 5 * time.Minute
    case .Long_Break:
        title = "Long Break"
        total = 15 * time.Minute
    }

    components.draw_timer_boxed(
        buf,
        {10, 5},
        60,
        pomodoro.remaining,
        total,
        pomodoro.timer_state,
        title,
    )
}
```

### Multi-Timer Display

```odin
Named_Timer :: struct {
    name: string,
    remaining: time.Duration,
    state: components.Timer_State,
}

draw_multi_timer :: proc(timers: []Named_Timer, buf: ^strings.Builder) {
    for timer, i in timers {
        y := 5 + (i * 2)

        // Draw timer name
        munin.print_at(buf, {5, y}, timer.name, .BrightYellow)

        // Draw timer
        components.draw_timer(
            buf,
            {30, y},
            timer.remaining,
            timer.state,
        )
    }
}

// Usage
timers := []Named_Timer{
    {"Tea", 3 * time.Minute, .Running},
    {"Laundry", 30 * time.Minute, .Running},
    {"Meeting", 1 * time.Hour, .Paused},
}

draw_multi_timer(timers, &buf)
```

### Timer Update Loop

```odin
Timer_App :: struct {
    remaining: time.Duration,
    total: time.Duration,
    state: components.Timer_State,
    last_update: time.Time,
}

update_timer :: proc(app: ^Timer_App) {
    if app.state != .Running {
        return
    }

    now := time.now()
    delta := time.diff(app.last_update, now)
    app.last_update = now

    app.remaining -= delta

    if app.remaining <= 0 {
        app.remaining = 0
        app.state = .Finished
        // Play sound or notification
    }
}

// Main loop
app := Timer_App{
    remaining = 5 * time.Minute,
    total = 5 * time.Minute,
    state = .Ready,
    last_update = time.now(),
}

for {
    update_timer(&app)

    buf := strings.builder_make()
    defer strings.builder_destroy(&buf)

    components.draw_timer_with_progress(
        &buf,
        {10, 10},
        app.remaining,
        app.total,
        app.state,
        50,
    )

    munin.flush(&buf)
    time.sleep(100 * time.Millisecond)
}
```

### Preset Selection Handler

```odin
handle_preset_selection :: proc(
    timer: ^Timer,
    key: Key,
    preset_count: int,
) {
    switch key {
    case .Num_1:
        if preset_count > 0 {
            select_preset(timer, 0)
        }
    case .Num_2:
        if preset_count > 1 {
            select_preset(timer, 1)
        }
    case .Num_3:
        if preset_count > 2 {
            select_preset(timer, 2)
        }
    case .Num_4:
        if preset_count > 3 {
            select_preset(timer, 3)
        }
    case .Num_5:
        if preset_count > 4 {
            select_preset(timer, 4)
        }
    }
}

select_preset :: proc(timer: ^Timer, index: int) {
    timer.selected_preset = index
    duration := time.Duration(timer.presets[index]) * time.Second
    timer.total = duration
    timer.remaining = duration
    timer.state = .Ready
}
```

### Kitchen Timer

```odin
Kitchen_Timer :: struct {
    name: string,
    remaining: time.Duration,
    total: time.Duration,
    state: components.Timer_State,
}

draw_kitchen_timer :: proc(timer: ^Kitchen_Timer, buf: ^strings.Builder) {
    // Title
    munin.print_at(buf, {5, 3}, timer.name, .BrightYellow)

    // Large timer display
    components.draw_timer(
        buf,
        {5, 5},
        timer.remaining,
        timer.state,
        false,
        .BrightYellow,
        .BrightGreen,
    )

    // Progress bar
    y := 7
    if timer.total > 0 {
        elapsed := timer.total - timer.remaining
        progress := int((time.duration_seconds(elapsed) / time.duration_seconds(timer.total)) * 100)

        components.draw_progress_bar(
            buf,
            {5, y},
            50,
            progress,
            .Blocks,
            .BrightGreen,
            .White,
            true,
        )
    }

    // Presets
    presets := []int{180, 300, 600, 900, 1200}  // 3m, 5m, 10m, 15m, 20m
    components.draw_timer_presets(buf, {5, 10}, presets, -1)
}
```

### Stopwatch Mode (Counting Up)

```odin
// Use negative total to indicate counting up
Stopwatch :: struct {
    elapsed: time.Duration,
    state: components.Timer_State,
}

draw_stopwatch :: proc(stopwatch: ^Stopwatch, buf: ^strings.Builder) {
    // Display elapsed time
    components.draw_timer(
        buf,
        {10, 10},
        stopwatch.elapsed,
        stopwatch.state,
        true,  // Show milliseconds for precision
        .BrightYellow,
        .BrightCyan,
    )
}
```

## Visual Reference

### Basic Timer
```
00:05:30 ▶ Running
```

### Timer States
```
00:10:00 ⏸ Ready      (Blue)
00:05:30 ▶ Running    (Green)
00:02:45 ⏸ Paused     (Yellow)
00:00:00 ✓ Finished   (Red)
```

### Timer with Milliseconds
```
00:00:10.500 ▶ Running
```

### Timer with Progress
```
00:03:00 ▶ Running

███████████████████████████████████░░░░░░░░░░░░░░  70%
```

### Boxed Timer
```
┌────────────────── Timer ──────────────────────┐
│                                                │
│       00:05:30 ▶ Running                       │
│                                                │
│       ████████████░░░░░░░░░  50%              │
│                                                │
│       [Space] Start/Pause  [r] Reset          │
└────────────────────────────────────────────────┘
```

### Preset Buttons
```
Quick Timers:

 30s   1m   5m   10m   15m
```

### Selected Preset
```
Quick Timers:

 30s  [ 1m ] 5m   10m   15m
       ^^^^
    (highlighted)
```

## Best Practices

1. **Update frequency** - Update timers every 100ms for smooth display
2. **State transitions** - Validate state changes (e.g., can't pause when ready)
3. **Time format** - Use `HH:MM:SS` for general timers, add `.mmm` for precision timing
4. **Progress indicators** - Always show progress for timers with known duration
5. **Presets** - Offer common durations: 30s, 1m, 5m, 10m, 15m, 30m
6. **Color coding** - Use yellow for warning when < 10 seconds remain
7. **Sound alerts** - Trigger audio notification when timer finishes

## Common Patterns

### Timer State Machine

```odin
toggle_timer :: proc(timer: ^Timer) {
    switch timer.state {
    case .Ready:
        timer.state = .Running
        timer.last_update = time.now()
    case .Running:
        timer.state = .Paused
    case .Paused:
        timer.state = .Running
        timer.last_update = time.now()
    case .Finished:
        // Do nothing or reset
    }
}

reset_timer :: proc(timer: ^Timer) {
    timer.remaining = timer.total
    timer.state = .Ready
}
```

### ETA Display

```odin
draw_timer_with_eta :: proc(
    remaining: time.Duration,
    buf: ^strings.Builder,
) {
    components.draw_timer(buf, {10, 10}, remaining, .Running)

    // Calculate finish time
    finish_time := time.now().Add(remaining)
    eta := fmt.tprintf("Finishes at: %s", time.format(finish_time, "15:04:05"))
    munin.print_at(buf, {10, 11}, eta, .BrightBlue)
}
```

## Integration

Requires:
- `munin` package for colors and cursor positioning
- `core:strings` for string building
- `core:fmt` for time formatting
- `core:time` for duration handling

Also integrates with:
- Progress component (for `draw_timer_with_progress`)
- Box component (for `draw_timer_boxed`)

## Notes

- Time is formatted as `HH:MM:SS` or `HH:MM:SS.mmm`
- Negative time values are displayed as `00:00:00`
- Progress calculation: `(total - remaining) / total * 100`
- State indicators use Unicode symbols (may require UTF-8 terminal)
- Preset buttons are automatically formatted based on duration
- Box height for `draw_timer_boxed()` is fixed at 8 lines
- Timer color automatically changes based on remaining time thresholds
