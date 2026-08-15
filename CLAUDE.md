# CLAUDE.md

## Project Overview

Munin is a lightweight Terminal User Interface (TUI) framework written in **Odin**, implementing the **Elm Architecture** pattern. It provides a functional, component-based approach to building interactive terminal applications with zero external dependencies.

## Build & Test Commands

```bash
# Run unit tests
make test              # or: odin test munin && odin test munin/components

# Run end-to-end tests (builds examples, drives them on a real pty)
make e2e               # or: python3 tests/e2e/test_examples.py
make e2e E2E=mouse     # filter by test name

# Everything: unit tests, examples, games, e2e
make check

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
  cmd.odin                 # Commands: scheduled/repeating messages, quit
  screen.odin              # Cell buffer: painting, clipping, composition, diffing
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
tests/e2e/                 # End-to-end tests: example binaries driven on a pty
  harness.py               # pty process driver + test registry
  test_examples.py         # Scenarios (terminal setup, input, signals, resize)
docs/                      # Component documentation (per-component .md files)
```

## Architecture

The framework follows the **Elm Architecture**:

1. **Model** - Application state (user-defined struct)
2. **Update** - Pure function that transforms state. `Program.update` is a
   single field of type `Update_Proc(Model, Msg)`, a union of the two accepted
   shapes:
   - `proc(msg: Msg, model: Model) -> (Model, bool)` - the bool requests quit
   - `proc(msg: Msg, model: Model, cmds: ^Cmd_Context(Msg)) -> Model` - can also
     schedule work (see Commands below)

   Both are dispatched from one place in the run loop; the only difference is
   how they say "stop".
3. **View** - Pure function: `proc(model: Model, buf: ^strings.Builder)` that renders to terminal

Programs are created with `make_program(init, update, view)` - which picks the
constructor from the update signature - and run with `run(&program, input_handler)`.

### Commands (`cmd.odin`)

An update that takes a `^Cmd_Context(Msg)` can express effects instead of
keeping timing state in globals:

- `cmd_send(cmds, msg)` - deliver a message on the next iteration
- `cmd_after(cmds, delay, msg)` / `cmd_every(cmds, interval, msg)` - schedule
  one or repeating, returning a handle for `cmd_cancel`
- `cmd_quit(cmds)` - stop the program

The run loop fires due timers alongside input and never sleeps past the next
scheduled message. `examples/forms` uses `cmd_every` for its cursor blink.

### Rendering modes

`run(..., render_mode: .Direct | .Cell_Diff)`.

- `.Direct` (default) writes the view exactly as composed.
- `.Cell_Diff` paints the view into a `Screen` (cell grid) and sends only the
  cells that changed - roughly 90% fewer bytes per keypress on a full-screen
  app. Fullscreen only; Inline always renders directly. `examples/lists` uses it.

### Two rendering styles, and how they compose

Components come in two shapes, and mixing them is the framework's main sharp
edge:

- **Positioned** (`draw_table`, `draw_list`, `draw_box*`, `draw_input`,
  `draw_tree`) emit absolute cursor moves. They cannot be measured, padded or
  joined - `style_render` sees them as one zero-width line.
- **Flowed** (`style_render`, `join_horizontal`, `join_vertical`,
  `render_tree`) produce newline-separated text that composes.

To place positioned components relative to each other, paint them into a
`Screen` with an origin and clip size (`screen_paint`), or compose grids with
`screen_blit`. That is also what gives them clipping - drawing past the edge is
dropped instead of corrupting the display.

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

Two layers:

**Unit tests** use Odin's built-in `@(test)` attribute, in `*_test.odin` files
alongside the module they test. Run with `make test`.
Coverage includes: ANSI escape stripping and sanitization, line counting with
Unicode/wide chars, terminal mode setup/teardown, input parsing (keyboard,
mouse, malformed sequences), style rendering and the box model, layout joins,
color parsing and emission, and every component.

**End-to-end tests** (`tests/e2e/`, Python 3 stdlib only) run the built example
binaries on a real pty. Run with `make e2e`. They cover what unit tests cannot:
alternate-screen handling, terminal restore on SIGTERM/SIGINT, real input byte
streams, input throughput, and window resizes. See `tests/e2e/README.md`.

When fixing a bug, add the regression test at the lowest layer that can catch
it — and prefer adding an e2e test too when the bug involves the terminal,
signals, or the input stream.

## Dependencies

**Zero external dependencies.** Only Odin core libraries are used: `core:fmt`, `core:mem`, `core:strings`, `core:time`, `core:unicode/utf8`, `core:c`, `core:sys/posix`.

## Environment Requirements

- **Odin compiler**: dev-2025-11 branch or later
- **System**: POSIX-compliant terminal (Linux/macOS) or Windows 10+ with virtual terminal processing
- **Build tools**: `make`, Odin compiler in PATH

## Memory Management

Three ownership conventions exist in the public API. Which one applies is not
visible from a call site, so it is stated on every procedure that returns a
string or a collection - check the doc comment before assuming.

**Caller-owned** - `delete()` the result:
`style_render`, `join_horizontal`, `join_vertical`, `render_tree`,
`render_tree_styled`, `input_clone_text`, `get_visible_nodes` (via
`destroy_visible_nodes`).

**Temp arena** - valid until the arena is reset, never `delete()`:
`sanitize_display`, `pad_string`, and anything a component allocates while
drawing. The run loop resets the temp arena once per iteration, so a view
function may allocate freely there.

**Borrowed** - a view into something else's memory, valid only while that
something is unchanged: `input_get_text` (aliases the input's buffer - use
`input_clone_text` to store it), `strip_ansi` (returns either the input string
itself or temp memory, so it must never be freed).

Rules of thumb:
- In view functions, prefer `context.temp_allocator`; a plain `strings.split`
  or `strings.repeat` there leaks once per redraw.
- A procedure must not allocate on a path the caller is expected to discard -
  returning freshly allocated memory alongside `ok = false` guarantees a leak
  at the idiomatic call site.
- `destroy_program` releases a program's buffers; `run` does it for you,
  including when terminal setup fails.
- Debug builds support `mem.Tracking_Allocator` for leak detection; several
  examples install one and print unfreed allocations on exit. Driving an
  example through `tests/e2e` and reading that report is the quickest way to
  find a per-frame leak.
