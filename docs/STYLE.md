# Style & Layout System

Munin version 0.2 introduces a powerful new **Styling** and **Layout** system inspired by Lipgloss. It allows for declarative, fluent-style definitions for styling text, borders, padding, and margins, along with robust Color support (Hex, ANSI256).

## 1. The `Style` Struct

The core of the system is the `Style` struct. You typically create one, chain methods to configure it, and then use it to render text.

```odin
import "munin"

// 1. Create a new style
s := munin.new_style()

// 2. Configure it (Chainable / Fluent)
s = munin.style_foreground(s, .BrightGreen)
s = munin.style_background_str(s, "#333333") // Hex color
s = munin.style_bold(s)
s = munin.style_padding_all(s, 1)
s = munin.style_border(s, munin.Border_Rounded)
s = munin.style_border_foreground(s, .BrightCyan)

// 3. Render raw text into a styled string
output := munin.style_render(s, "Hello Styles!")
defer delete(output) // IMPORTANT: You own the returned string memory!

fmt.println(output)
```

## 2. Colors

`munin.Color` is now a union type supporting:
*   **`munin.Basic_Color`**: Standard 16 ANSI colors (e.g. `.Red`, `.BrightBlue`, `.Reset`).
*   **`munin.RGB`**: TrueColor (24-bit) struct `{r, g, b}`.
*   **`munin.ANSI256`**: 8-bit color index (0-255).

### Usage

**Basic Colors:**
```odin
s = munin.style_foreground(s, munin.Basic_Color.Red)
// or inferred if context allows:
s = munin.style_foreground(s, .Red) 
```

**Hex / RGB:**
```odin
// Using helper for hex strings
s = munin.style_foreground_str(s, "#FF00FF") 
s = munin.style_background_str(s, "#FAFAFA")

// Manual RGB
s = munin.style_foreground(s, munin.RGB{255, 0, 0})
```

**ANSI 256:**
```odin
// Using helper string "0" - "255"
s = munin.style_foreground_str(s, "208") 
// Manual
s = munin.style_foreground(s, munin.ANSI256(208))
```

## 3. Box Model

The styling system supports a CSS-like box model:
*   **Content**: The text itself.
*   **Padding**: Space *inside* the border.
*   **Border**: The decorative edge.
*   **Margin**: Space *outside* the border.

```odin
s = munin.style_padding(s, 1, 2, 1, 2) // Top, Right, Bottom, Left
s = munin.style_margin_all(s, 2)
s = munin.style_width(s, 50)           // Force content width (excluding padding/border)
```

## 4. Borders

Predefined border styles are available:
*   `munin.Border_Normal` (Single line)
*   `munin.Border_Rounded`
*   `munin.Border_Double`
*   `munin.Border_Hidden`

```odin
s = munin.style_border(s, munin.Border_Rounded)
s = munin.style_border_foreground(s, .BrightYellow)
```

## 5. Layout (Composition)

You can compose multiple rendered strings horizontally or vertically using `join_horizontal` and `join_vertical`. These respect ANSI codes and handle alignment.

### Horizontal Join
Places blocks side-by-side.

```odin
left_block := munin.style_render(style_a, "Left")
defer delete(left_block)

right_block := munin.style_render(style_b, "Right")
defer delete(right_block)

// Join with Center alignment (vertical alignment relative to largest block)
// Gap of 2 spaces
joined := munin.join_horizontal(.Center, {left_block, right_block}, 2)
defer delete(joined)

fmt.println(joined)
```

### Vertical Join
Places blocks top-to-bottom.

```odin
top_block := ...
bottom_block := ...

// Join with Center alignment (horizontal alignment)
joined_v := munin.join_vertical(.Center, {top_block, bottom_block}, 1)
defer delete(joined_v)

fmt.println(joined_v)
```

## 6. Memory Management

**Important:** Functions like `style_render`, `join_horizontal`, and `join_vertical` return a new allocated `string`. 
**You own this memory.** You must call `delete()` on the result when you are finished printing or using it to prevent memory leaks.

```odin
res := munin.style_render(s, "Text")
fmt.println(res)
delete(res) // Clean up
```
