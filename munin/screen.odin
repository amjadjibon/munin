package munin

import "core:fmt"
import "core:mem"
import "core:strings"
import "core:unicode/utf8"

// ============================================================
// CELL BUFFER
// ============================================================
//
// A Screen is a grid of cells that understands the output components already
// produce - absolute cursor moves, SGR colour and attribute changes, erases,
// text - and paints it into that grid instead of sending it to the terminal.
//
// That solves three separate problems at once, without changing a single
// component:
//
//   Clipping     - anything drawn outside the grid is dropped, instead of
//                  wrapping and corrupting the display.
//   Composition  - painting with an origin (and a clip rectangle) puts a
//                  component inside a region, so absolutely-positioned
//                  components can be placed side by side.
//   Redraw cost  - two screens can be diffed, so a frame sends only the cells
//                  that actually changed rather than the whole view.

Attr :: enum u8 {
	Bold,
	Dim,
	Italic,
	Underline,
	Blink,
	Reverse,
}

Attrs :: bit_set[Attr;u8]

Cell :: struct {
	r:     rune, // 0 means "blank"
	fg:    Color,
	bg:    Color,
	attrs: Attrs,
	// Cells covered by the left half of a wide character carry width 0 so the
	// renderer knows to skip them.
	width: u8,
}

Screen :: struct {
	cells:     []Cell,
	width:     int,
	height:    int,
	allocator: mem.Allocator,
}

// The painter's state: where the next character goes and how it is styled.
@(private)
Pen :: struct {
	x, y:  int,
	fg:    Color,
	bg:    Color,
	attrs: Attrs,
}

BLANK_CELL :: Cell {
	r     = ' ',
	width = 1,
}

// ============================================================
// LIFECYCLE
// ============================================================

screen_make :: proc(width, height: int, allocator := context.allocator) -> Screen {
	s := Screen {
		allocator = allocator,
	}
	screen_resize(&s, width, height)
	return s
}

// A zero-value Screen carries a nil allocator - which is what a Program's
// screens are before the first frame. Fall back to the context allocator
// rather than handing nil to make().
@(private)
screen_allocator :: proc(s: ^Screen) -> mem.Allocator {
	if s.allocator.procedure == nil {
		return context.allocator
	}
	return s.allocator
}

screen_destroy :: proc(s: ^Screen) {
	delete(s.cells, screen_allocator(s))
	s.cells = nil
	s.width = 0
	s.height = 0
}

// Resize, discarding the contents. Returns true if the size changed.
screen_resize :: proc(s: ^Screen, width, height: int) -> bool {
	w := max(width, 0)
	h := max(height, 0)
	if s.width == w && s.height == h {
		return false
	}

	a := screen_allocator(s)
	delete(s.cells, a)
	s.allocator = a

	cells, err := make([]Cell, w * h, a)
	if err != nil {
		// Keep the invariant len(cells) == width*height, so every bounds
		// check in screen_set/screen_cell still holds.
		s.cells = nil
		s.width = 0
		s.height = 0
		return true
	}

	s.cells = cells
	s.width = w
	s.height = h
	screen_clear(s)
	return true
}

screen_clear :: proc(s: ^Screen) {
	for i in 0 ..< len(s.cells) {
		s.cells[i] = BLANK_CELL
	}
}

screen_cell :: proc(s: ^Screen, x, y: int) -> (Cell, bool) {
	if x < 0 || y < 0 || x >= s.width || y >= s.height {
		return {}, false
	}
	return s.cells[y * s.width + x], true
}

@(private)
screen_set :: proc(s: ^Screen, x, y: int, c: Cell) {
	if x < 0 || y < 0 || x >= s.width || y >= s.height {
		return // clipped
	}
	s.cells[y * s.width + x] = c
}

// ============================================================
// PAINTING
// ============================================================

// Paint terminal output into the screen.
//
// `origin` offsets every absolute cursor position in the input, so a
// component that draws at {0,0} can be placed anywhere; `clip` bounds what it
// is allowed to touch (an empty clip means the whole screen).
screen_paint :: proc(s: ^Screen, output: string, origin := Vec2i{0, 0}, clip_size := Vec2i{0, 0}) {
	clip_w := clip_size.x > 0 ? clip_size.x : s.width - origin.x
	clip_h := clip_size.y > 0 ? clip_size.y : s.height - origin.y

	pen := Pen {
		x  = 0,
		y  = 0,
		fg = Basic_Color.Reset,
		bg = Basic_Color.Reset,
	}

	put :: proc(s: ^Screen, pen: ^Pen, r: rune, origin: Vec2i, clip_w, clip_h: int) {
		w := rune_visual_width(r)
		if w == 0 {
			return // zero-width: control characters and the like
		}

		// Inside the region?
		if pen.y >= 0 && pen.y < clip_h && pen.x >= 0 && pen.x < clip_w {
			screen_set(
				s,
				origin.x + pen.x,
				origin.y + pen.y,
				Cell{r = r, fg = pen.fg, bg = pen.bg, attrs = pen.attrs, width = u8(w)},
			)
			if w == 2 && pen.x + 1 < clip_w {
				// Continuation half of a wide character.
				screen_set(
					s,
					origin.x + pen.x + 1,
					origin.y + pen.y,
					Cell{r = 0, fg = pen.fg, bg = pen.bg, attrs = pen.attrs, width = 0},
				)
			}
		}
		pen.x += w
	}

	i := 0
	for i < len(output) {
		b := output[i]

		switch b {
		case '\n':
			pen.y += 1
			pen.x = 0
			i += 1
			continue
		case '\r':
			pen.x = 0
			i += 1
			continue
		case '\t':
			pen.x = ((pen.x / 8) + 1) * 8
			i += 1
			continue
		case 0x1b:
			i = paint_escape(s, &pen, output, i, origin, clip_w, clip_h)
			continue
		}

		r, size := utf8.decode_rune_in_string(output[i:])
		if size == 0 {
			i += 1
			continue
		}
		put(s, &pen, r, origin, clip_w, clip_h)
		i += size
	}
}

// Handle one escape sequence, returning the index just past it.
@(private)
paint_escape :: proc(
	s: ^Screen,
	pen: ^Pen,
	output: string,
	start: int,
	origin: Vec2i,
	clip_w, clip_h: int,
) -> int {
	// Anything that is not a CSI is skipped whole (OSC, DCS, two-byte forms).
	if start + 1 >= len(output) || output[start + 1] != '[' {
		return skip_escape_sequence(output, start)
	}

	end := skip_escape_sequence(output, start)
	if end <= start + 2 {
		return end
	}

	final := output[end - 1]
	params := output[start + 2:end - 1]

	// Private sequences (?25l, ?1049h, ...) do not affect the grid.
	if len(params) > 0 && params[0] == '?' {
		return end
	}

	switch final {
	case 'H', 'f':
		row, col := 1, 1
		semi := -1
		for j in 0 ..< len(params) {
			if params[j] == ';' {
				semi = j
				break
			}
		}
		if semi == -1 {
			row = csi_number(params, 1)
		} else {
			row = csi_number(params[:semi], 1)
			col = csi_number(params[semi + 1:], 1)
		}
		pen.y = row - 1
		pen.x = col - 1

	case 'A':
		pen.y -= csi_number(params, 1)
	case 'B':
		pen.y += csi_number(params, 1)
	case 'C':
		pen.x += csi_number(params, 1)
	case 'D':
		pen.x -= csi_number(params, 1)
	case 'G':
		pen.x = csi_number(params, 1) - 1

	case 'J':
		mode := csi_number(params, 0)
		erase_display(s, pen^, mode, origin, clip_w, clip_h)
	case 'K':
		mode := csi_number(params, 0)
		erase_line(s, pen^, mode, origin, clip_w, clip_h)

	case 'm':
		apply_sgr(pen, params)
	}

	return end
}

@(private)
csi_number :: proc(s: string, fallback: int) -> int {
	if len(s) == 0 {
		return fallback
	}
	v := 0
	for i in 0 ..< len(s) {
		if s[i] < '0' || s[i] > '9' {
			return fallback
		}
		v = v * 10 + int(s[i] - '0')
		if v > 9999 {
			return 9999
		}
	}
	return v
}

@(private)
blank_at :: proc(s: ^Screen, pen: Pen, x, y: int, origin: Vec2i) {
	screen_set(s, origin.x + x, origin.y + y, Cell{r = ' ', bg = pen.bg, width = 1})
}

@(private)
erase_line :: proc(s: ^Screen, pen: Pen, mode: int, origin: Vec2i, clip_w, clip_h: int) {
	if pen.y < 0 || pen.y >= clip_h {
		return
	}
	start, end := 0, clip_w
	switch mode {
	case 0:
		start = max(pen.x, 0) // cursor to end of line
	case 1:
		end = min(pen.x + 1, clip_w) // start of line to cursor
	case 2:
	// whole line
	}
	for x in start ..< end {
		blank_at(s, pen, x, pen.y, origin)
	}
}

@(private)
erase_display :: proc(s: ^Screen, pen: Pen, mode: int, origin: Vec2i, clip_w, clip_h: int) {
	switch mode {
	case 0:
		// Cursor to end of screen
		erase_line(s, pen, 0, origin, clip_w, clip_h)
		for y in max(pen.y + 1, 0) ..< clip_h {
			for x in 0 ..< clip_w {
				blank_at(s, pen, x, y, origin)
			}
		}
	case 1:
		// Start of screen to cursor
		for y in 0 ..< min(max(pen.y, 0), clip_h) {
			for x in 0 ..< clip_w {
				blank_at(s, pen, x, y, origin)
			}
		}
		erase_line(s, pen, 1, origin, clip_w, clip_h)
	case:
		// Whole screen
		for y in 0 ..< clip_h {
			for x in 0 ..< clip_w {
				blank_at(s, pen, x, y, origin)
			}
		}
	}
}

@(private)
apply_sgr :: proc(pen: ^Pen, params: string) {
	if len(params) == 0 {
		pen.fg = Basic_Color.Reset
		pen.bg = Basic_Color.Reset
		pen.attrs = {}
		return
	}

	// Split on ';' without allocating.
	values: [16]int
	count := 0
	start := 0
	for i := 0; i <= len(params); i += 1 {
		if i == len(params) || params[i] == ';' {
			if count < len(values) {
				values[count] = csi_number(params[start:i], 0)
				count += 1
			}
			start = i + 1
		}
	}

	i := 0
	for i < count {
		v := values[i]
		switch v {
		case 0:
			pen.fg = Basic_Color.Reset
			pen.bg = Basic_Color.Reset
			pen.attrs = {}
		case 1:
			pen.attrs += {.Bold}
		case 2:
			pen.attrs += {.Dim}
		case 3:
			pen.attrs += {.Italic}
		case 4:
			pen.attrs += {.Underline}
		case 5:
			pen.attrs += {.Blink}
		case 7:
			pen.attrs += {.Reverse}
		case 22:
			pen.attrs -= {.Bold, .Dim}
		case 23:
			pen.attrs -= {.Italic}
		case 24:
			pen.attrs -= {.Underline}
		case 25:
			pen.attrs -= {.Blink}
		case 27:
			pen.attrs -= {.Reverse}
		case 39:
			pen.fg = Basic_Color.Reset
		case 49:
			pen.bg = Basic_Color.Reset
		case 38, 48:
			// Extended colour: 38;5;n or 38;2;r;g;b
			is_fg := v == 38
			if i + 1 < count && values[i + 1] == 5 && i + 2 < count {
				c := Color(ANSI256(values[i + 2]))
				if is_fg {pen.fg = c} else {pen.bg = c}
				i += 2
			} else if i + 1 < count && values[i + 1] == 2 && i + 4 < count {
				c := Color(
					RGB{r = u8(values[i + 2]), g = u8(values[i + 3]), b = u8(values[i + 4])},
				)
				if is_fg {pen.fg = c} else {pen.bg = c}
				i += 4
			}
		case:
			if v >= 30 && v <= 37 {
				pen.fg = basic_from_sgr(v - 30, false)
			} else if v >= 40 && v <= 47 {
				pen.bg = basic_from_sgr(v - 40, false)
			} else if v >= 90 && v <= 97 {
				pen.fg = basic_from_sgr(v - 90, true)
			} else if v >= 100 && v <= 107 {
				pen.bg = basic_from_sgr(v - 100, true)
			}
		}
		i += 1
	}
}

@(private)
basic_from_sgr :: proc(index: int, bright: bool) -> Color {
	table := [8]Basic_Color {
		.Black,
		.Red,
		.Green,
		.Yellow,
		.Blue,
		.Magenta,
		.Cyan,
		.White,
	}
	bright_table := [8]Basic_Color {
		.BrightBlack,
		.BrightRed,
		.BrightGreen,
		.BrightYellow,
		.BrightBlue,
		.BrightMagenta,
		.BrightCyan,
		.BrightWhite,
	}
	if index < 0 || index > 7 {
		return Basic_Color.Reset
	}
	return bright ? bright_table[index] : table[index]
}

// ============================================================
// RENDERING
// ============================================================

// Write the escape sequences needed to turn `prev` into `cur`.
//
// Passing a nil (or differently sized) `prev` redraws everything. Only cells
// that differ are emitted, and the cursor is only repositioned when the next
// changed cell is not where the cursor already is.
screen_render_diff :: proc(cur: ^Screen, prev: ^Screen, buf: ^strings.Builder) {
	full := prev == nil || prev.width != cur.width || prev.height != cur.height

	pen_valid := false
	pen: Cell
	cursor_x, cursor_y := -1, -1

	if full {
		strings.write_string(buf, "\x1b[H\x1b[2J")
		cursor_x, cursor_y = 0, 0
	}

	for y in 0 ..< cur.height {
		for x in 0 ..< cur.width {
			c := cur.cells[y * cur.width + x]

			// The right half of a wide character is emitted with its left.
			if c.width == 0 {
				continue
			}

			if !full {
				p := prev.cells[y * prev.width + x]
				if cells_equal(c, p) {
					continue
				}
			}

			if cursor_x != x || cursor_y != y {
				fmt.sbprintf(buf, "\x1b[%d;%dH", y + 1, x + 1)
				cursor_x, cursor_y = x, y
			}

			if !pen_valid || !style_equal(c, pen) {
				write_cell_style(buf, c, pen, pen_valid)
				pen = c
				pen_valid = true
			}

			r := c.r == 0 ? ' ' : c.r
			strings.write_rune(buf, r)
			cursor_x += int(max(c.width, 1))
		}
	}

	if pen_valid {
		strings.write_string(buf, "\x1b[0m")
	}
}

@(private)
cells_equal :: proc(a, b: Cell) -> bool {
	return a.r == b.r && a.width == b.width && style_equal(a, b)
}

@(private)
style_equal :: proc(a, b: Cell) -> bool {
	return a.fg == b.fg && a.bg == b.bg && a.attrs == b.attrs
}

@(private)
write_cell_style :: proc(buf: ^strings.Builder, c: Cell, pen: Cell, pen_valid: bool) {
	// Attributes can only be added incrementally; removing one means starting
	// from a reset.
	needs_reset := !pen_valid || (pen.attrs - c.attrs) != {}
	if needs_reset {
		strings.write_string(buf, "\x1b[0m")
	}

	added := needs_reset ? c.attrs : c.attrs - pen.attrs
	if .Bold in added {strings.write_string(buf, "\x1b[1m")}
	if .Dim in added {strings.write_string(buf, "\x1b[2m")}
	if .Italic in added {strings.write_string(buf, "\x1b[3m")}
	if .Underline in added {strings.write_string(buf, "\x1b[4m")}
	if .Blink in added {strings.write_string(buf, "\x1b[5m")}
	if .Reverse in added {strings.write_string(buf, "\x1b[7m")}

	if needs_reset || c.fg != pen.fg {
		if !is_color_reset(c.fg) {
			write_ansi_color(buf, c.fg, false)
		} else if !needs_reset {
			strings.write_string(buf, "\x1b[39m")
		}
	}
	if needs_reset || c.bg != pen.bg {
		if !is_color_reset(c.bg) {
			write_ansi_color(buf, c.bg, true)
		} else if !needs_reset {
			strings.write_string(buf, "\x1b[49m")
		}
	}
}

// Render the whole screen, ignoring any previous state.
screen_render :: proc(cur: ^Screen, buf: ^strings.Builder) {
	screen_render_diff(cur, nil, buf)
}

// Copy `src` into `dst` at `pos`, clipping at the destination's edges.
// This is how two independently drawn components end up side by side.
screen_blit :: proc(dst: ^Screen, src: ^Screen, pos: Vec2i) {
	for y in 0 ..< src.height {
		for x in 0 ..< src.width {
			screen_set(dst, pos.x + x, pos.y + y, src.cells[y * src.width + x])
		}
	}
}

// Visible text of a row, with no styling. Mostly useful for tests.
screen_row_text :: proc(s: ^Screen, y: int, allocator := context.temp_allocator) -> string {
	if y < 0 || y >= s.height {
		return ""
	}

	b := strings.builder_make(allocator)
	for x in 0 ..< s.width {
		c := s.cells[y * s.width + x]
		if c.width == 0 {
			continue
		}
		strings.write_rune(&b, c.r == 0 ? ' ' : c.r)
	}
	return strings.trim_right_space(strings.to_string(b))
}
