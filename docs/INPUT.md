# Input Component

The Input component provides a full-featured text input field with cursor management, validation, and multiple display styles for terminal-based forms.

## Overview

Located in `components/input.odin`, this component offers comprehensive text input functionality including password masking, cursor navigation, validation, and various visual styles.

## Input Styles

### `Input_Style` enum

- **Plain** - Simple underlined input field
- **Box** - Input surrounded by a box border
- **Inline** - No border, just the text

## State Management

### `Input_State`

Core state structure for managing input fields:

```odin
Input_State :: struct {
    buffer:             [dynamic]u8,
    cursor_pos:         int,
    is_focused:         bool,
    is_password:        bool,
    max_length:         int,
    placeholder:        string,
    cursor_blink_state: bool,
}
```

**Fields:**
- `buffer` - Dynamic byte array storing the input text
- `cursor_pos` - Current cursor position in the buffer
- `is_focused` - Whether the input field has focus
- `is_password` - If true, displays asterisks instead of actual text
- `max_length` - Maximum allowed input length
- `placeholder` - Text displayed when input is empty
- `cursor_blink_state` - Current blink state for cursor animation

## State Management Functions

### `make_input_state()`

Creates a new input state with the specified configuration.

```odin
make_input_state :: proc(
    max_length: int = 256,
    placeholder: string = "",
) -> Input_State
```

**Parameters:**
- `max_length` - Maximum characters allowed (default: 256)
- `placeholder` - Placeholder text when empty (default: "")

**Returns:** Initialized `Input_State`

**Example:**
```odin
email_input := make_input_state(100, "Enter your email...")
```

---

### `destroy_input_state()`

Cleans up and frees the input state's buffer.

```odin
destroy_input_state :: proc(state: ^Input_State)
```

**Important:** Always call this to prevent memory leaks.

**Example:**
```odin
defer destroy_input_state(&email_input)
```

## Input Manipulation Functions

### `input_add_char()`

Adds a character at the current cursor position.

```odin
input_add_char :: proc(state: ^Input_State, char: rune)
```

- Automatically handles UTF-8 encoding
- Respects `max_length` constraint
- Inserts at cursor position and advances cursor

---

### `input_backspace()`

Removes the character before the cursor (backspace key behavior).

```odin
input_backspace :: proc(state: ^Input_State)
```

---

### `input_delete()`

Removes the character at the cursor position (delete key behavior).

```odin
input_delete :: proc(state: ^Input_State)
```

---

### Cursor Navigation

```odin
input_cursor_left  :: proc(state: ^Input_State)  // Move cursor left
input_cursor_right :: proc(state: ^Input_State)  // Move cursor right
input_cursor_home  :: proc(state: ^Input_State)  // Move to start
input_cursor_end   :: proc(state: ^Input_State)  // Move to end
```

---

### `input_toggle_cursor_blink()`

Toggles the cursor blink state for animation.

```odin
input_toggle_cursor_blink :: proc(state: ^Input_State)
```

Call this periodically (e.g., every 500ms) to create a blinking cursor effect.

---

### `input_get_text()`

Retrieves the current input text as a string.

```odin
input_get_text :: proc(state: ^Input_State) -> string
```

**Returns:** Current input text

---

### `input_clear()`

Clears all input and resets cursor to start.

```odin
input_clear :: proc(state: ^Input_State)
```

---

### Query Functions

```odin
input_get_length :: proc(state: ^Input_State) -> int   // Get text length
input_is_empty   :: proc(state: ^Input_State) -> bool  // Check if empty
```

## Validation Functions

### `input_is_valid_email()`

Basic email validation.

```odin
input_is_valid_email :: proc(state: ^Input_State) -> bool
```

**Checks:**
- Minimum length of 5 characters
- Contains `@` symbol (not at start)
- Contains `.` after the `@`

---

### `input_is_valid_phone()`

Basic phone number validation.

```odin
input_is_valid_phone :: proc(state: ^Input_State) -> bool
```

**Checks:**
- Minimum length of 10 characters
- Only contains digits and phone characters: `0-9`, `-`, `(`, `)`, space

## Rendering Functions

### `draw_input()`

Renders the input field with full customization.

```odin
draw_input :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    state: ^Input_State,
    width: int,
    style: Input_Style = .Box,
    label: string = "",
    label_color: munin.Color = munin.Basic_Color.BrightYellow,
    text_color: munin.Color = munin.Basic_Color.White,
    cursor_color: munin.Color = munin.Basic_Color.BrightGreen,
    placeholder_color: munin.Color = munin.Basic_Color.BrightBlue,
)
```

**Parameters:**
- `buf` - String builder for output
- `pos` - Position to draw the input
- `state` - Input state to render
- `width` - Total width of the input field
- `style` - Visual style (default: `.Box`)
- `label` - Optional label above input
- `label_color` - Label text color
- `text_color` - Input text color
- `cursor_color` - Cursor color
- `placeholder_color` - Placeholder text color

**Features:**
- Focused inputs show highlighted borders (cyan)
- Unfocused inputs show normal borders (white)
- Blinking cursor when focused
- Automatic text truncation if exceeds width
- Password masking with asterisks

---

### `draw_input_form()`

Renders multiple input fields as a form with focus management.

```odin
draw_input_form :: proc(
    buf: ^strings.Builder,
    pos: munin.Vec2i,
    fields: []struct {
        label: string,
        state: ^Input_State,
    },
    focused_index: int,
    width: int = 40,
)
```

**Parameters:**
- `buf` - String builder for output
- `pos` - Starting position
- `fields` - Array of field definitions (label + state)
- `focused_index` - Index of currently focused field
- `width` - Width of each input field

## Usage Examples

### Basic Input Field

```odin
import "components"
import "core:strings"

// Create input state
username := components.make_input_state(50, "Enter username...")
defer components.destroy_input_state(&username)

// Set focus
username.is_focused = true

// Render
buf := strings.builder_make()
defer strings.builder_destroy(&buf)

components.draw_input(
    &buf,
    {10, 5},
    &username,
    40,
    .Box,
    "Username:",
)
```

### Password Input

```odin
password := components.make_input_state(100)
password.is_password = true
password.is_focused = true

components.draw_input(
    &buf,
    {10, 10},
    &password,
    40,
    .Box,
    "Password:",
)
```

### Input Form

```odin
name_input := components.make_input_state(100, "Full name...")
email_input := components.make_input_state(100, "email@example.com")
phone_input := components.make_input_state(20, "(555) 123-4567")

fields := []struct {
    label: string,
    state: ^Input_State,
}{
    {"Full Name", &name_input},
    {"Email", &email_input},
    {"Phone", &phone_input},
}

components.draw_input_form(&buf, {10, 5}, fields, 0, 50)
```

### Input with Validation

```odin
email := components.make_input_state(100)

// ... user inputs text ...

if components.input_is_valid_email(&email) {
    // Process valid email
    email_text := components.input_get_text(&email)
} else {
    // Show error
}
```

### Cursor Blink Animation

```odin
// In your main loop (call every ~500ms):
components.input_toggle_cursor_blink(&input_state)
```

### Handling Keyboard Input

```odin
// Example event handler
handle_key :: proc(state: ^Input_State, key: Key) {
    switch key {
    case .Backspace:
        components.input_backspace(state)
    case .Delete:
        components.input_delete(state)
    case .Left:
        components.input_cursor_left(state)
    case .Right:
        components.input_cursor_right(state)
    case .Home:
        components.input_cursor_home(state)
    case .End:
        components.input_cursor_end(state)
    case .Char:
        components.input_add_char(state, key.char)
    }
}
```

## Visual Reference

### Box Style (Focused)
```
Username:
┌──────────────────────────────────┐
│Hello█orld                        │
└──────────────────────────────────┘
```

### Plain Style
```
Username:
Hello█orld
──────────────────────────────────
```

### Inline Style
```
Username: Hello█orld
```

### Password Field
```
Password:
┌──────────────────────────────────┐
│********█                         │
└──────────────────────────────────┘
```

## Best Practices

1. **Always destroy state** - Use `defer destroy_input_state()` to prevent memory leaks
2. **Cursor blink timing** - Toggle cursor every 400-600ms for smooth animation
3. **Focus management** - Only one input should have `is_focused = true` at a time
4. **Validation timing** - Validate on submit or blur, not on every keystroke
5. **Max length** - Set reasonable `max_length` values based on expected input
6. **Placeholder text** - Use clear, example-based placeholders
7. **Label clarity** - Keep labels short and descriptive

## Integration

Requires:
- `munin` package for terminal operations
- `core:strings` for string building
- `core:fmt` for formatting

## Notes

- UTF-8 characters are fully supported
- Cursor position is byte-based but correctly handles multi-byte characters
- Text is automatically truncated if it exceeds the visible width
- The component does not handle keyboard input directly - integrate with your event system
