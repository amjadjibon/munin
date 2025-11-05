# Text Component

The Text component provides various text rendering utilities including word wrapping, headings, centering, banners, and label-value pairs.

## Overview

Located in `components/text.odin`, this component offers essential text formatting and layout functions for terminal applications.

## Functions

### `draw_text_wrapped()`

Renders text with automatic word wrapping to fit within a specified width.

```odin
draw_text_wrapped :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    max_width: int,
    text: string,
    color: munin.Color = .White,
) -> int
```

**Parameters:**
- `buf` - String builder for output
- `pos` - Starting position for the text
- `max_width` - Maximum line width in characters
- `text` - Text to render (words separated by spaces)
- `color` - Text color (default: `.White`)

**Returns:** Number of lines used

**Features:**
- Automatically breaks on word boundaries
- Respects specified maximum width
- Returns line count for layout calculations
- Preserves word integrity (no mid-word breaks)

**Example:**
```odin
text := "This is a long paragraph that needs to be wrapped to fit within the available space."
lines_used := draw_text_wrapped(&buf, {5, 5}, 40, text, .White)
```

---

### `draw_heading()`

Renders a heading with optional underline.

```odin
draw_heading :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    text: string,
    level: int = 1,
    color: munin.Color = .BrightCyan,
)
```

**Parameters:**
- `buf` - String builder for output
- `pos` - Position for the heading
- `text` - Heading text
- `level` - Heading level (1 or 2+)
- `color` - Heading color (default: `.BrightCyan`)

**Features:**
- Level 1 headings are underlined with `═` characters
- All headings are rendered in bold
- Underline matches the text length

**Example:**
```odin
draw_heading(&buf, {5, 5}, "Chapter 1: Introduction", 1, .BrightYellow)
```

Output:
```
Chapter 1: Introduction
═══════════════════════
```

---

### `draw_text_centered()`

Renders centered text within a specified screen width.

```odin
draw_text_centered :: proc(
    buf: ^strings.Builder,
    y, screen_width: int,
    text: string,
    color: munin.Color = .White,
)
```

**Parameters:**
- `buf` - String builder for output
- `y` - Vertical position
- `screen_width` - Total screen width for centering calculation
- `text` - Text to center
- `color` - Text color (default: `.White`)

**Features:**
- Automatically calculates horizontal center position
- Useful for titles and centered messages

**Example:**
```odin
draw_text_centered(&buf, 10, 80, "Welcome to My Application", .BrightCyan)
```

---

### `draw_banner()`

Renders text in a colored banner with padding.

```odin
draw_banner :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    width: int,
    text: string,
    bg_color: munin.Color = .BrightBlue,
    text_color: munin.Color = .White,
)
```

**Parameters:**
- `buf` - String builder for output
- `pos` - Banner position
- `width` - Total banner width
- `text` - Text to display in banner
- `bg_color` - Background color (default: `.BrightBlue`)
- `text_color` - Text color (default: `.White`)

**Features:**
- Text is centered within the banner
- Full-width background color
- Bold text by default
- Padding automatically calculated

**Example:**
```odin
draw_banner(&buf, {5, 5}, 60, "IMPORTANT NOTICE", .BrightRed, .White)
```

Output (with background):
```
                    IMPORTANT NOTICE
```

---

### `draw_label_value()`

Renders a label-value pair with customizable separator.

```odin
draw_label_value :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    label, value: string,
    label_color: munin.Color = .BrightYellow,
    value_color: munin.Color = .White,
    separator: string = ": ",
)
```

**Parameters:**
- `buf` - String builder for output
- `pos` - Starting position
- `label` - Label text
- `value` - Value text
- `label_color` - Label color (default: `.BrightYellow`)
- `value_color` - Value color (default: `.White`)
- `separator` - Separator between label and value (default: `": "`)

**Features:**
- Label, separator, and value are drawn inline
- Different colors for label and value
- Separator shown in bright blue
- Useful for displaying key-value information

**Example:**
```odin
draw_label_value(&buf, {5, 5}, "Status", "Active", .BrightYellow, .BrightGreen)
```

Output:
```
Status: Active
```

## Usage Examples

### Wrapped Paragraph

```odin
import "components"
import "core:strings"

buf := strings.builder_make()
defer strings.builder_destroy(&buf)

long_text := "Lorem ipsum dolor sit amet, consectetur adipiscing elit. " +
             "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. " +
             "Ut enim ad minim veniam, quis nostrud exercitation ullamco."

lines := components.draw_text_wrapped(&buf, {5, 5}, 60, long_text, .White)
// Use 'lines' to calculate next element position
next_y := 5 + lines + 1
```

### Document with Headings

```odin
draw_document :: proc(buf: ^strings.Builder) {
    y := 5

    // Main heading
    components.draw_heading(&buf, {5, y}, "User Guide", 1, .BrightCyan)
    y += 3

    // Section heading
    components.draw_heading(&buf, {5, y}, "Installation", 2, .BrightYellow)
    y += 2

    // Content
    text := "To install the application, follow these steps..."
    lines := components.draw_text_wrapped(&buf, {5, y}, 70, text, .White)
    y += lines + 2

    // Another section
    components.draw_heading(&buf, {5, y}, "Configuration", 2, .BrightYellow)
    y += 2

    text = "Configure the application by editing the config file..."
    lines = components.draw_text_wrapped(&buf, {5, y}, 70, text, .White)
}
```

### Centered Title Screen

```odin
draw_title_screen :: proc(buf: ^strings.Builder, screen_width, screen_height: int) {
    center_y := screen_height / 2 - 3

    // Title
    components.draw_text_centered(
        buf,
        center_y,
        screen_width,
        "MY AWESOME APPLICATION",
        .BrightCyan,
    )

    // Subtitle
    components.draw_text_centered(
        buf,
        center_y + 2,
        screen_width,
        "Version 1.0.0",
        .BrightBlue,
    )

    // Prompt
    components.draw_text_centered(
        buf,
        center_y + 4,
        screen_width,
        "Press any key to continue...",
        .BrightYellow,
    )
}
```

### Multiple Banners

```odin
draw_notification_banners :: proc(buf: ^strings.Builder) {
    // Success banner
    components.draw_banner(
        buf,
        {0, 0},
        80,
        "✓ Operation Successful",
        .Green,
        .White,
    )

    // Warning banner
    components.draw_banner(
        buf,
        {0, 5},
        80,
        "⚠ Warning: Low Disk Space",
        .Yellow,
        .Black,
    )

    // Error banner
    components.draw_banner(
        buf,
        {0, 10},
        80,
        "✗ Error: Connection Failed",
        .Red,
        .White,
    )
}
```

### System Information Display

```odin
System_Info :: struct {
    hostname: string,
    os: string,
    kernel: string,
    uptime: string,
    memory: string,
    cpu: string,
}

draw_system_info :: proc(info: System_Info, buf: ^strings.Builder) {
    y := 5

    components.draw_heading(&buf, {5, y}, "System Information", 1, .BrightCyan)
    y += 3

    components.draw_label_value(&buf, {5, y}, "Hostname", info.hostname)
    y += 1

    components.draw_label_value(&buf, {5, y}, "Operating System", info.os)
    y += 1

    components.draw_label_value(&buf, {5, y}, "Kernel", info.kernel)
    y += 1

    components.draw_label_value(&buf, {5, y}, "Uptime", info.uptime)
    y += 1

    components.draw_label_value(&buf, {5, y}, "Memory", info.memory)
    y += 1

    components.draw_label_value(&buf, {5, y}, "CPU", info.cpu)
}
```

### Status Report

```odin
draw_status_report :: proc(buf: ^strings.Builder) {
    y := 3

    // Banner header
    components.draw_banner(&buf, {0, y}, 80, "SYSTEM STATUS REPORT", .BrightBlue, .White)
    y += 3

    // Status items with color coding
    components.draw_label_value(
        &buf, {5, y},
        "Database", "Connected",
        .BrightYellow, .BrightGreen,
    )
    y += 1

    components.draw_label_value(
        &buf, {5, y},
        "API Server", "Running",
        .BrightYellow, .BrightGreen,
    )
    y += 1

    components.draw_label_value(
        &buf, {5, y},
        "Cache", "Offline",
        .BrightYellow, .BrightRed,
    )
    y += 1

    components.draw_label_value(
        &buf, {5, y},
        "Queue", "Processing",
        .BrightYellow, .BrightYellow,
    )
}
```

### Help Text with Sections

```odin
draw_help_text :: proc(buf: ^strings.Builder) {
    y := 3

    components.draw_heading(&buf, {5, y}, "Help", 1, .BrightCyan)
    y += 3

    // Commands section
    components.draw_heading(&buf, {5, y}, "Available Commands", 2, .BrightYellow)
    y += 2

    commands := []struct {
        cmd: string,
        desc: string,
    }{
        {"start", "Start the application"},
        {"stop", "Stop the application"},
        {"status", "Show current status"},
        {"help", "Display this help message"},
    }

    for command in commands {
        components.draw_label_value(
            &buf, {7, y},
            command.cmd, command.desc,
            .BrightGreen, .White,
            " - ",
        )
        y += 1
    }

    y += 2

    // Options section
    components.draw_heading(&buf, {5, y}, "Options", 2, .BrightYellow)
    y += 2

    options_text := "Use --verbose for detailed output. " +
                    "Use --quiet to suppress non-error messages. " +
                    "Use --config to specify a custom configuration file."

    lines := components.draw_text_wrapped(&buf, {7, y}, 70, options_text, .White)
}
```

### Configuration Display

```odin
Config :: struct {
    server: string,
    port: int,
    timeout: int,
    debug: bool,
}

draw_config :: proc(config: Config, buf: ^strings.Builder) {
    y := 5

    components.draw_banner(&buf, {5, y}, 60, "Current Configuration", .BrightBlue, .White)
    y += 3

    components.draw_label_value(&buf, {5, y}, "Server", config.server)
    y += 1

    components.draw_label_value(&buf, {5, y}, "Port", fmt.tprintf("%d", config.port))
    y += 1

    components.draw_label_value(&buf, {5, y}, "Timeout", fmt.tprintf("%d seconds", config.timeout))
    y += 1

    debug_text := config.debug ? "Enabled" : "Disabled"
    debug_color := config.debug ? munin.Color.BrightYellow : munin.Color.White
    components.draw_label_value(&buf, {5, y}, "Debug Mode", debug_text, .BrightYellow, debug_color)
}
```

### Multi-Column Label-Value Layout

```odin
draw_two_column_info :: proc(buf: ^strings.Builder) {
    y := 5
    col1_x := 5
    col2_x := 45

    // Left column
    components.draw_label_value(&buf, {col1_x, y}, "First Name", "John")
    components.draw_label_value(&buf, {col2_x, y}, "Last Name", "Doe")
    y += 1

    components.draw_label_value(&buf, {col1_x, y}, "Email", "john@example.com")
    components.draw_label_value(&buf, {col2_x, y}, "Phone", "+1-555-0100")
    y += 1

    components.draw_label_value(&buf, {col1_x, y}, "City", "New York")
    components.draw_label_value(&buf, {col2_x, y}, "Country", "USA")
}
```

### Welcome Message

```odin
draw_welcome :: proc(buf: ^strings.Builder, username: string, screen_width: int) {
    y := 5

    // Centered welcome banner
    components.draw_banner(&buf, {0, y}, screen_width, "WELCOME", .BrightCyan, .White)
    y += 3

    // Centered greeting
    greeting := fmt.tprintf("Hello, %s!", username)
    components.draw_text_centered(buf, y, screen_width, greeting, .BrightYellow)
    y += 2

    // Centered instructions
    components.draw_text_centered(buf, y, screen_width, "Select an option below to get started", .White)
}
```

## Visual Reference

### Heading Level 1
```
My Heading
══════════
```

### Heading Level 2+
```
My Heading
```

### Centered Text (screen_width = 60)
```
                     Centered Text
```

### Banner (width = 40)
```
           BANNER TEXT
```

### Label-Value Pair
```
Label: Value
```

### Wrapped Text (max_width = 40)
```
This is a long paragraph that will
be wrapped automatically to fit
within the specified width limit.
```

## Best Practices

1. **Word wrapping** - Use `max_width` slightly less than screen width for margins
2. **Heading hierarchy** - Use level 1 for main sections, level 2+ for subsections
3. **Centering** - Account for actual screen width when centering
4. **Banner width** - Match banner width to screen width for full-width effect
5. **Label length** - Keep labels concise (under 20 characters) for readability
6. **Separator choice** - Use `: ` for general info, ` - ` for lists, ` = ` for configs
7. **Color contrast** - Ensure good contrast between text and background in banners

## Common Patterns

### Auto-Layout Vertical Stack

```odin
Text_Block :: struct {
    content: string,
    color: munin.Color,
}

draw_text_blocks :: proc(blocks: []Text_Block, buf: ^strings.Builder, max_width: int) {
    y := 5
    for block in blocks {
        lines := components.draw_text_wrapped(
            buf,
            {5, y},
            max_width,
            block.content,
            block.color,
        )
        y += lines + 1  // Add spacing between blocks
    }
}
```

### Dynamic Banner Width

```odin
draw_responsive_banner :: proc(buf: ^strings.Builder, text: string, y: int) {
    screen_width := get_terminal_width()
    components.draw_banner(buf, {0, y}, screen_width, text, .BrightBlue, .White)
}
```

## Integration

Requires:
- `munin` package for colors and cursor positioning
- `core:strings` for string manipulation

## Notes

- Word wrapping breaks only on spaces (no hyphenation)
- Headings always render text in bold
- Centered text calculation is based on string length, not visual width
- Banners fill the entire width with background color
- Label-value pairs are rendered on a single line
- Separator in label-value pairs is always rendered in bright blue
- `draw_text_wrapped()` returns line count for layout calculations
