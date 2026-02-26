# CLAUDE.md

## Project Overview

Munin is a lightweight Terminal User Interface (TUI) framework written in **Odin**, implementing the **Elm Architecture** pattern. It provides a functional, component-based approach to building interactive terminal applications with zero external dependencies.

## Build & Test Commands

```bash
# Run tests
make test              # or: odin test munin

# Build all examples
make examples          # or: ./examples.sh

# Build and run a specific example
odin run examples/counter -file

# Build a specific example to binary
odin build examples/counter -out:bin/counter

# Clean build artifacts
make clean
```

## Project Structure

```
munin/                      # Core framework library
  munin.odin               # Main framework: Program struct, run loop, rendering
  input.odin               # Input types and public API (Key_Event, Mouse_Event)
  input_posix.odin         # POSIX input handling (read_key, read_input)
  input_windows.odin       # Windows input handling
  colors.odin              # Color system (Basic_Color, RGB, ANSI256)
  style.odin               # CSS-like styling (borders, padding, margins)
  layout.odin              # Layout composition (join_horizontal, join_vertical)
  utils.odin               # Rendering utilities (strip_ansi, count_lines, etc.)
  border.odin              # Border character definitions
  terminal.odin            # Terminal abstraction
  terminal_posix.odin      # POSIX terminal setup (raw mode, SIGWINCH)
  terminal_windows.odin    # Windows terminal setup
  *_test.odin              # Test files for each module
  components/              # Reusable UI components
    box.odin, input.odin, list.odin, pagination.odin,
    progress.odin, spinner.odin, table.odin, text.odin,
    timer.odin, tree.odin
examples/                  # 20 working example applications
games/                     # Game implementations (2048)
docs/                      # Component documentation (per-component .md files)
```

## Architecture

The framework follows the **Elm Architecture** with three core concepts:

1. **Model** - Application state (user-defined struct)
2. **Update** - Pure function: `proc(msg: Msg, model: Model) -> (Model, bool)` that transforms state
3. **View** - Pure function: `proc(model: Model, buf: ^strings.Builder)` that renders to terminal

Programs are created with `make_program(init, update, view)` and run with `run(&program, input_handler)`.

Platform-specific code is separated into `*_posix.odin` and `*_windows.odin` files using Odin's conditional compilation (`when ODIN_OS != .Windows`).

## Code Conventions

### Naming
- **Types/structs**: `PascalCase` with underscores for multi-word (`Key_Event`, `Mouse_Button`, `Screen_Mode`)
- **Functions/procs**: `snake_case` (`make_program`, `read_key`, `strip_ansi`)
- **Constants**: `SCREAMING_SNAKE_CASE` (`FRAME_TIME`, `TIOCGWINSZ`)
- **Enum values**: `PascalCase` (`.BrightGreen`, `.Fullscreen`)

### Patterns
- Fluent/chainable API for styling: `style = munin.style_bold(style)`
- `Maybe(T)` for optional returns (e.g., `read_key() -> Maybe(Key_Event)`)
- `defer delete()` for heap-allocated strings returned by `style_render`, `join_horizontal`, `join_vertical`
- Pre-allocated string builders (4KB default) for rendering
- Tracking allocators in debug mode (`when ODIN_DEBUG`)

### File Organization
- One module per concern (input, colors, style, layout, terminal)
- Platform-specific files use `_posix` / `_windows` suffixes
- Test files use `_test.odin` suffix alongside the module they test
- Section headers use ASCII art dividers (`// ====...`)

## Testing

Tests use Odin's built-in `@(test)` attribute. Run with `odin test munin` or `make test`.

Test coverage includes: ANSI escape stripping, line counting with Unicode/wide chars, terminal mode setup/teardown, input parsing (keyboard and mouse events), rendering utilities, and color parsing.

## Dependencies

**Zero external dependencies.** Only Odin core libraries are used: `core:fmt`, `core:mem`, `core:strings`, `core:time`, `core:unicode/utf8`, `core:c`, `core:sys/posix`.

## Environment Requirements

- **Odin compiler**: dev-2025-11 branch or later
- **System**: POSIX-compliant terminal (Linux/macOS) or Windows 10+ with virtual terminal processing
- **Build tools**: `make`, Odin compiler in PATH

## Memory Management

- Style render functions return heap-allocated strings that must be `delete()`'d
- Use `context.temp_allocator` for temporary allocations within view functions (cleared each frame)
- Debug builds support `mem.Tracking_Allocator` for leak detection
