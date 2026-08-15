package munin

import "core:strings"

// Join positions
Position :: enum {
	Top,
	Bottom,
	Left,
	Right,
	Center,
}

// Join strings horizontally with a given gap and alignment
join_horizontal :: proc(position: Position, models: []string, gap: int = 0) -> string {
	if len(models) == 0 {
		return ""
	}

	// Scratch data lives in the temp allocator: this runs once per frame and
	// the per-frame temp arena is reset by the run loop anyway.
	all_lines := make([][]string, len(models), context.temp_allocator)
	// Column widths are computed once here. They used to be recomputed with
	// get_max_width() inside the inner render loop, which re-split and
	// re-measured an entire model string for every blank cell.
	widths := make([]int, len(models), context.temp_allocator)

	max_height := 0

	for model, idx in models {
		lines := strings.split(model, "\n", context.temp_allocator)
		// Filter out trailing empty line if it exists (common with split on string ending in \n)
		count := len(lines)
		if count > 0 && lines[count - 1] == "" {
			count -= 1
		}

		if count > max_height {
			max_height = count
		}

		all_lines[idx] = lines[:count]

		w := 0
		for i in 0 ..< count {
			lw := get_visible_width(lines[i])
			if lw > w {
				w = lw
			}
		}
		widths[idx] = w
	}

	b := strings.builder_make()

	for y in 0 ..< max_height {
		for i in 0 ..< len(all_lines) {
			lines := all_lines[i]
			h := len(lines)

			line_idx := -1
			switch position {
			case .Top:
				if y < h {line_idx = y}
			case .Bottom:
				if y >= max_height - h {line_idx = y - (max_height - h)}
			case .Center:
				start_y := (max_height - h) / 2
				if y >= start_y && y < start_y + h {line_idx = y - start_y}
			case .Left, .Right:
				if y < h {line_idx = y}
			}

			// Every cell occupies the full column width, whether it holds a
			// line or not. Writing a short line unpadded (as this used to)
			// pushes every column to its right out of alignment on that row.
			written := 0
			if line_idx >= 0 && line_idx < h {
				strings.write_string(&b, lines[line_idx])
				written = get_visible_width(lines[line_idx])
			}
			for k in written ..< widths[i] {
				strings.write_byte(&b, ' ')
			}

			if i < len(all_lines) - 1 {
				for k in 0 ..< gap {
					strings.write_byte(&b, ' ')
				}
			}
		}
		if y < max_height - 1 {
			strings.write_string(&b, "\n")
		}
	}

	res := strings.clone(strings.to_string(b))
	strings.builder_destroy(&b)
	return res
}

join_vertical :: proc(position: Position, models: []string, gap: int = 0) -> string {
	if len(models) == 0 {
		return ""
	}

	b := strings.builder_make()

	max_width := 0
	for model in models {
		w := get_max_width(model)
		if w > max_width {
			max_width = w
		}
	}

	for i in 0 ..< len(models) {
		model := models[i]
		lines := strings.split(model, "\n", context.temp_allocator)

		for line_idx in 0 ..< len(lines) {
			line := lines[line_idx]
			line_width := get_visible_width(line)
			padding := max_width - line_width

			left_pad := 0
			right_pad := 0

			switch position {
			case .Left:
				right_pad = padding
			case .Right:
				left_pad = padding
			case .Center:
				left_pad = padding / 2
				right_pad = padding - left_pad
			case .Top, .Bottom:
				right_pad = padding
			}

			for k in 0 ..< left_pad {strings.write_byte(&b, ' ')}
			strings.write_string(&b, line)
			for k in 0 ..< right_pad {strings.write_byte(&b, ' ')}

			// Always add newline unless it is the very last line of very last model?
			// Usually easier to consistency add.
			if line_idx < len(lines) - 1 || i < len(models) - 1 || gap > 0 {
				strings.write_string(&b, "\n")
			}
		}

		if i < len(models) - 1 {
			for k in 0 ..< gap {
				strings.write_string(&b, "\n")
			}
		}
	}

	res := strings.clone(strings.to_string(b))
	strings.builder_destroy(&b)
	return res
}

// Width of the widest line in s. Scans in place - no allocation, since this
// is called repeatedly on the render path.
get_max_width :: proc(s: string) -> int {
	max_w := 0
	start := 0
	for i in 0 ..< len(s) {
		if s[i] == '\n' {
			w := get_visible_width(s[start:i])
			if w > max_w {
				max_w = w
			}
			start = i + 1
		}
	}
	w := get_visible_width(s[start:])
	if w > max_w {
		max_w = w
	}
	return max_w
}

import "core:unicode/utf8"

get_visible_width :: proc(s: string) -> int {
	width := 0

	// We need to iterate over the string byte by byte for ANSI,
	// but when not in ANSI, we should count runes.
	// Mixing byte iteration and rune decoding:

	i := 0
	for i < len(s) {
		if s[i] == 0x1b {
			// Skip the whole escape sequence. Terminating only on 'm'
			// (as this used to) means a cursor-move, erase or OSC sequence
			// swallows the entire rest of the string and the width comes
			// back as 0, silently breaking padding and alignment.
			i = skip_escape_sequence(s, i)
			continue
		}

		// Not in escape, decode rune
		r, size := utf8.decode_rune_in_string(s[i:])
		if r == utf8.RUNE_ERROR || size == 0 {
			i += 1
		} else {
			width += rune_width(r)
			i += size
		}
	}
	return width
}

// Given index i pointing at an ESC byte, return the index just past the end of
// the escape sequence.
@(private)
skip_escape_sequence :: proc(s: string, start: int) -> int {
	i := start + 1
	if i >= len(s) {
		return len(s)
	}

	switch s[i] {
	case '[':
		// CSI: parameters/intermediates, then a final byte 0x40-0x7E.
		i += 1
		for i < len(s) {
			b := s[i]
			i += 1
			if b >= 0x40 && b <= 0x7E {
				break
			}
		}
	case ']', 'P', 'X', '^', '_':
		// OSC/DCS/SOS/PM/APC: terminated by BEL or ST (ESC \).
		i += 1
		for i < len(s) {
			if s[i] == 0x07 {
				i += 1
				break
			}
			if s[i] == 0x1b && i + 1 < len(s) && s[i + 1] == '\\' {
				i += 2
				break
			}
			i += 1
		}
	case:
		// Two-byte escape (e.g. ESC c, ESC 7).
		i += 1
	}

	return i
}

// Visual width of a rune in terminal cells.
// Forwards to rune_visual_width (munin.odin) so layout measurement and line
// counting always agree; keeping two tables meant the same emoji could be
// 1 cell wide to one and 2 to the other.
rune_width :: proc(r: rune) -> int {
	return rune_visual_width(r)
}
