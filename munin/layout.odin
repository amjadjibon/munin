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

	all_lines: [dynamic][dynamic]string
	defer {
		for lines in all_lines {
			delete(lines)
		}
		delete(all_lines)
	}

	max_height := 0

	for model in models {
		lines := strings.split(model, "\n")
		// Filter out trailing empty line if it exists (common with split on string ending in \n)
		count := len(lines)
		if count > 0 && lines[count - 1] == "" {
			count -= 1
		}

		if count > max_height {
			max_height = count
		}

		dyn_lines: [dynamic]string
		for i in 0 ..< count {
			append(&dyn_lines, lines[i])
		}
		append(&all_lines, dyn_lines)
		delete(lines) // Free the slice
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

			if line_idx >= 0 && line_idx < h {
				strings.write_string(&b, lines[line_idx])
			} else {
				w := get_max_width(models[i])
				for k in 0 ..< w {
					strings.write_byte(&b, ' ')
				}
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

	return strings.to_string(b)
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
		lines := strings.split(model, "\n")
		defer delete(lines)

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

	return strings.to_string(b)
}

get_max_width :: proc(s: string) -> int {
	lines := strings.split(s, "\n")
	defer delete(lines)
	max_w := 0
	for line in lines {
		w := get_visible_width(line)
		if w > max_w {
			max_w = w
		}
	}
	return max_w
}

import "core:unicode/utf8"

get_visible_width :: proc(s: string) -> int {
	width := 0
	in_escape := false

	// We need to iterate over the string byte by byte for ANSI,
	// but when not in ANSI, we should count runes.
	// Mixing byte iteration and rune decoding:

	i := 0
	for i < len(s) {
		if s[i] == '\x1b' {
			in_escape = true
			i += 1
			continue
		}

		if in_escape {
			if s[i] == 'm' {
				in_escape = false
			}
			i += 1
			continue
		}

		// Not in escape, decode rune
		r, size := utf8.decode_rune_in_string(s[i:])
		if r == utf8.RUNE_ERROR {
			i += 1
		} else {
			// TODO: Check for double-width characters (East Asian Width)
			// For now, assume 1 rune = 1 column unless it's a zero-width char?
			// Basic fix: Count RUNES, not BYTES.
			width += 1
			i += size
		}
	}
	return width
}
