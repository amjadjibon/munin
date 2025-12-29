# Box Component

The Box component provides functions for drawing decorative boxes with various styles, titles, and fills.

## Overview

Located in `munin/components/box.odin`, this component offers flexible box-drawing capabilities for creating visual containers in terminal applications.

## Box Styles

The component supports five different border styles:

### `Box_Style` enum

- **Single** - Single-line borders using Unicode box-drawing characters (`┌─┐│└┘`)
- **Double** - Double-line borders (`╔═╗║╚╝`)
- **Rounded** - Rounded corners with single lines (`╭─╮│╰╯`)
- **Bold** - Bold/thick line borders (`┏━┓┃┗┛`)
- **Ascii** - ASCII-compatible borders using `+`, `-`, and `|`

## Functions

### `draw_box_styled()`

Draws a basic box with the specified style and color.

```odin
draw_box_styled :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    width, height: int,
    style: Box_Style = .Single,
    color: munin.Color = munin.Basic_Color.Reset,
)
```

**Parameters:**
- `buf` - String builder to write the output
- `pos` - Top-left corner position (x, y coordinates)
- `width` - Box width in characters
- `height` - Box height in characters
- `style` - Border style (default: `.Single`)
- `color` - Border color (default: `.Reset`)

**Example:**
```odin
draw_box_styled(buf, {10, 5}, 40, 10, .Rounded, .BrightCyan)
```

---

### `draw_box_titled()`

Draws a box with a title embedded in the top border.

```odin
draw_box_titled :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    width, height: int,
    title: string,
    style: Box_Style = .Single,
    color: munin.Color = munin.Basic_Color.Reset,
    title_color: munin.Color = munin.Basic_Color.BrightWhite,
)
```

**Parameters:**
- `buf` - String builder to write the output
- `pos` - Top-left corner position
- `width` - Box width in characters
- `height` - Box height in characters
- `title` - Title text to display in the top border
- `style` - Border style (default: `.Single`)
- `color` - Border color (default: `.Reset`)
- `title_color` - Title text color (default: `.BrightWhite`)

**Features:**
- Title is automatically truncated if it exceeds `width - 4`
- Title is bold by default
- Title appears centered in the top border with spacing

**Example:**
```odin
draw_box_titled(buf, {10, 5}, 40, 10, "Settings", .Double, .BrightBlue, .BrightYellow)
```

---

### `draw_box_filled()`

Draws a box with a filled background color.

```odin
draw_box_filled :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    width, height: int,
    bg_color: munin.Color,
    border_style: Box_Style = .Single,
    border_color: munin.Color = munin.Basic_Color.Reset,
)
```

**Parameters:**
- `buf` - String builder to write the output
- `pos` - Top-left corner position
- `width` - Box width in characters
- `height` - Box height in characters
- `bg_color` - Background fill color
- `border_style` - Border style (default: `.Single`)
- `border_color` - Border color (default: `.Reset`)

**Features:**
- Fills the entire box area with the specified background color
- Border is drawn on top of the filled background

**Example:**
```odin
draw_box_filled(buf, {10, 5}, 40, 10, .BrightBlue, .Rounded, .BrightCyan)
```

## Usage Examples

### Basic Box
```odin
import "munin/components"
import "core:strings"

buf := strings.builder_make()
defer strings.builder_destroy(&buf)

// Draw a simple single-line box
components.draw_box_styled(&buf, {5, 5}, 30, 8, .Single, .White)
```

### Titled Dialog Box
```odin
// Create a dialog-style box with a title
components.draw_box_titled(
    &buf,
    {10, 10},
    50, 15,
    "User Information",
    .Double,
    .BrightCyan,
    .BrightYellow,
)
```

### Highlighted Panel
```odin
// Create a panel with colored background
components.draw_box_filled(
    &buf,
    {5, 20},
    40, 10,
    .Blue,           // Background color
    .Rounded,        // Border style
    .BrightWhite,    // Border color
)
```

## Visual Reference

```
Single:          Double:          Rounded:
┌─────────┐      ╔═════════╗      ╭─────────╮
│         │      ║         ║      │         │
│         │      ║         ║      │         │
└─────────┘      ╚═════════╝      ╰─────────╯

Bold:            Ascii:
┏━━━━━━━━━┓      +---------+
┃         ┃      |         |
┃         ┃      |         |
┗━━━━━━━━━┛      +---------+
```

## Data Structures

### `Box_Border`

Internal structure defining the characters used for each border style:

```odin
Box_Border :: struct {
    top_left:     string,
    top_right:    string,
    bottom_left:  string,
    bottom_right: string,
    horizontal:   string,
    vertical:     string,
}
```

## Best Practices

1. **Choose appropriate styles** - Use `.Ascii` for maximum compatibility, Unicode styles for better aesthetics
2. **Size validation** - Ensure `width >= 2` and `height >= 2` for proper rendering
3. **Title length** - Keep titles shorter than `width - 4` to avoid truncation
4. **Color contrast** - Use contrasting colors for border and title for better readability
5. **Nested boxes** - Leave adequate spacing when nesting boxes within each other

## Integration

This component integrates with the Munin terminal library and requires:
- `munin` package for color and cursor positioning
- `core:strings` for string building

## Notes

- All drawing operations append to the provided `strings.Builder`
- Positions use zero-based coordinates
- Colors are reset after drawing to avoid affecting subsequent output
- Box borders are inclusive in the specified width and height
