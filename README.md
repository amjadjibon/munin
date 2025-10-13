# Munin

A lightweight, elegant Terminal UI (TUI) framework for Odin, inspired by the Elm Architecture.

## Features

- **Elm Architecture Pattern**: Clean separation of Model, Update, and View
- **Cross-Platform**: Works on Linux, macOS, and Windows
- **Event-Driven Rendering**: Only redraws when state changes
- **Window Resize Detection**: Automatically detects and responds to terminal resize events
- **Rich Color Support**: 16 ANSI colors with bright variants
- **Memory Safe**: Built-in allocator support with debug-time memory tracking
- **Zero Dependencies**: Uses only Odin core libraries

## Installation

Clone the repository and import it into your Odin project:

```bash
git clone https://github.com/amjadjibon/munin.git
```

## Quick Start

Here's a minimal counter example:

```odin
package main

import munin "../../munin"
import "core:fmt"
import "core:strings"

// 1. Define your Model
Model :: struct {
	counter: int,
}

init :: proc() -> Model {
	return Model{counter = 0}
}

// 2. Define your Messages
Increment :: struct {}
Decrement :: struct {}
Quit :: struct {}

Msg :: union {
	Increment,
	Decrement,
	Quit,
}

// 3. Define your Update function
update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case Increment:
		new_model.counter += 1
	case Decrement:
		new_model.counter -= 1
	case Quit:
		should_quit = true
	}

	return new_model, should_quit
}

// 4. Define your View function
view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)
	munin.print_at(buf, {2, 2}, fmt.tprintf("Counter: "), .BrightGreen)
	munin.print_at(buf, {11, 2}, fmt.tprintf("%d", model.counter), .BrightRed)
	munin.print_at(buf, {2, 4}, "Press space to increment, d to decrement, q to quit", .White)
}

// 5. Define your Input handler
input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_key().?; ok {
		if event.key == .Char {
			switch event.char {
			case ' ':
				return Increment{}
			case 'd':
				return Decrement{}
			case 'q', 'Q', 3:
				// q, Q, or Ctrl+C
				return Quit{}
			}
		}
	}
	return nil
}

// 6. Run your program
main :: proc() {
	program := munin.make_program(init, update, view)
	munin.run(&program, input_handler)
}
```

## Building and Running

```bash
# Build the example
odin build example/counter -out:counter

# Run the example
./counter
```

## Output
<img src="./example/counter/counter.gif" alt="Counter Example" width="600">

## Core Concepts

### The Elm Architecture

Munin follows the Elm Architecture pattern with three main components:

1. **Model**: Your application state
2. **Update**: Pure function that transforms the model based on messages
3. **View**: Pure function that renders the model to the terminal

### Program Lifecycle

```odin
// Create a program without subscriptions
program := munin.make_program(init, update, view)

// Or create a program with subscriptions (for time-based events)
program := munin.make_program(init, update, view, subscriptions)

// Run the program
munin.run(&program, input_handler, target_fps = 60)
```

## API Reference

### Core Functions

#### `make_program`
```odin
// Without subscriptions
make_program :: proc(
    init: proc() -> Model,
    update: proc(msg: Msg, model: Model) -> (Model, bool),
    view: proc(model: Model, buf: ^strings.Builder),
    allocator := context.allocator,
) -> Program(Model, Msg)

// With subscriptions
make_program :: proc(
    init: proc() -> Model,
    update: proc(msg: Msg, model: Model) -> (Model, bool),
    view: proc(model: Model, buf: ^strings.Builder),
    subscriptions: proc(Model) -> Maybe(Msg),
    allocator := context.allocator,
) -> Program(Model, Msg)
```

#### `run`
```odin
run :: proc(
    program: ^Program(Model, Msg),
    input_handler: proc() -> Maybe(Msg),
    target_fps: i64 = 60,
)
```

### Rendering Functions

#### Screen Control
```odin
clear_screen :: proc(buf: ^strings.Builder)
move_cursor :: proc(buf: ^strings.Builder, pos: Vec2i)
hide_cursor :: proc(buf: ^strings.Builder)
show_cursor :: proc(buf: ^strings.Builder)
```

#### Drawing
```odin
// Draw a box at position with width and height
draw_box :: proc(buf: ^strings.Builder, pos: Vec2i, width, height: int, color: Color = .Reset)

// Print text at position
print_at :: proc(buf: ^strings.Builder, pos: Vec2i, text: string, color: Color = .Reset)

// Print formatted text at position
printf_at :: proc(buf: ^strings.Builder, pos: Vec2i, color: Color, format: string, args: ..any)

// Draw centered title
draw_title :: proc(
    buf: ^strings.Builder,
    pos: Vec2i,
    width: int,
    title: string,
    color: Color = .Reset,
    bold := false,
)
```

#### Text Styling
```odin
set_color :: proc(buf: ^strings.Builder, color: Color)
set_bg_color :: proc(buf: ^strings.Builder, color: Color)
set_bold :: proc(buf: ^strings.Builder)
set_dim :: proc(buf: ^strings.Builder)
set_underline :: proc(buf: ^strings.Builder)
set_blink :: proc(buf: ^strings.Builder)
set_reverse :: proc(buf: ^strings.Builder)
reset_style :: proc(buf: ^strings.Builder)
```

### Window Functions

```odin
// Get current terminal size
get_window_size :: proc() -> (width, height: int, ok: bool)

// Set terminal window title
set_window_title :: proc(buf: ^strings.Builder, title: string)
```

### Input Functions

```odin
// Read keyboard input (non-blocking)
read_key :: proc() -> Maybe(Key_Event)
```

### Types

#### `Vec2i`
2D integer vector for positions:
```odin
Vec2i :: [2]int

// Usage
pos := Vec2i{x, y}
munin.print_at(buf, {10, 5}, "Hello", .Green)
```

#### `Color`
Available colors:
```odin
Color :: enum {
    Reset,
    // Standard colors
    Black, Red, Green, Yellow, Blue, Magenta, Cyan, White,
    // Bright colors
    BrightBlack, BrightRed, BrightGreen, BrightYellow,
    BrightBlue, BrightMagenta, BrightCyan, BrightWhite,
    // Aliases
    Gray,  // Same as BrightBlack
}
```

#### `Key_Event`
```odin
Key_Event :: struct {
    key:  Key_Type,
    char: rune,
}

Key_Type :: enum {
    Char,
    Up,
    Down,
    Left,
    Right,
    Enter,
    Backspace,
    Delete,
    Escape,
    Tab,
}
```

## Memory Management

Munin supports custom allocators and memory tracking:

```odin
main :: proc() {
    // Debug-time memory tracking
    when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }

    // Create program with custom allocator
    program := munin.make_program(init, update, view, allocator = context.allocator)
    munin.run(&program, input_handler)
}
```

## Advanced Features

### Subscriptions

Subscriptions allow you to handle time-based or external events:

```odin
subscriptions :: proc(model: Model) -> Maybe(Msg) {
    // Check for tick every frame
    if model.should_tick {
        return Tick{}
    }
    return nil
}

main :: proc() {
    program := munin.make_program(init, update, view, subscriptions)
    munin.run(&program, input_handler)
}
```

### Window Resize Handling

Munin automatically detects window resizes. Get the current size in your view:

```odin
view :: proc(model: Model, buf: ^strings.Builder) {
    munin.clear_screen(buf)

    width, height, ok := munin.get_window_size()
    if !ok {
        width = 80
        height = 24
    }

    // Center content based on terminal size
    center_x := width / 2
    center_y := height / 2

    munin.print_at(buf, {center_x - 5, center_y}, "Centered!", .Green)
}
```

### Custom Frame Rate

Control the rendering frame rate:

```odin
main :: proc() {
    program := munin.make_program(init, update, view)
    munin.run(&program, input_handler, target_fps = 30)  // 30 FPS
}
```

## Examples

Check out the `example/counter` directory for a complete, feature-rich example that demonstrates:

- Responsive layout that adapts to terminal size
- Colored box drawing
- Text styling and formatting
- Keyboard input handling
- Memory tracking in debug builds

## Performance Tips

1. **Event-Driven Rendering**: Munin only redraws when state changes. Avoid setting `needs_redraw` unnecessarily.

2. **String Builder Efficiency**: The framework uses a pre-allocated string builder (4KB default) to minimize allocations.

3. **Frame Rate Control**: Set an appropriate `target_fps` based on your needs. 60 FPS is the default, but 30 FPS is often sufficient.

4. **Minimize View Complexity**: Keep your view function efficient since it's called every frame when redrawing.

## Platform Support

- **Linux**: Full support
- **macOS**: Full support
- **Windows**: Not supported

## License

This project is open source. See LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Acknowledgments

Inspired by:
- The Elm Architecture
- Bubble Tea (Go TUI framework)
- Termbox and other terminal libraries
