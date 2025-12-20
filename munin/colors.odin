package munin

import "core:fmt"
import "core:strconv"
import "core:strings"

// ============================================================
// Colors
// ============================================================

// Standard ANSI colors (4-bit)
Basic_Color :: enum {
	Reset,
	Black,
	Red,
	Green,
	Yellow,
	Blue,
	Magenta,
	Cyan,
	White,
	BrightBlack,
	BrightRed,
	BrightGreen,
	BrightYellow,
	BrightBlue,
	BrightMagenta,
	BrightCyan,
	BrightWhite,
}

// 24-bit True Color
RGB :: struct {
	r, g, b: u8,
}

// 8-bit ANSI Color
ANSI256 :: distinct int

// Universal Color Type
Color :: union {
	Basic_Color,
	RGB,
	ANSI256,
}

// ============================================================
// PARSING
// ============================================================

// Parse a color string:
// - "#RRGGBB" or "#RGB" -> RGB
// - "0"-"255" -> ANSI256
// - "red", "blue", etc. -> Basic_Color (TODO: Implement names)
color_from_string :: proc(s: string) -> Maybe(Color) {
	if s == "" {return nil}

	// 1. Hex
	if strings.has_prefix(s, "#") {
		hex := s[1:]
		if len(hex) == 6 {
			if val, ok := strconv.parse_u64(hex, 16); ok {
				return RGB {
					r = u8((val >> 16) & 0xFF),
					g = u8((val >> 8) & 0xFF),
					b = u8(val & 0xFF),
				}
			}
		} else if len(hex) == 3 {
			if val, ok := strconv.parse_u64(hex, 16); ok {
				r := u8((val >> 8) & 0xF)
				g := u8((val >> 4) & 0xF)
				b := u8(val & 0xF)
				return RGB{r = r * 17, g = g * 17, b = b * 17}
			}
		}
	}

	// 2. Numeric (ANSI 256)
	if val, ok := strconv.parse_int(s); ok {
		if val >= 0 && val <= 255 {
			return ANSI256(val)
		}
	}

	// 3. Named Basic Colors (Simple fallback)
	// Make case insensitive?
	lower := strings.to_lower(s) // Allocates, TODO: Optimize or use generic cmp
	defer delete(lower)

	switch lower {
	case "black":
		return Basic_Color.Black
	case "red":
		return Basic_Color.Red
	case "green":
		return Basic_Color.Green
	case "yellow":
		return Basic_Color.Yellow
	case "blue":
		return Basic_Color.Blue
	case "magenta":
		return Basic_Color.Magenta
	case "cyan":
		return Basic_Color.Cyan
	case "white":
		return Basic_Color.White
	}

	return nil
}

// ============================================================
// RENDERING
// ============================================================

// Convert color to ANSI escape code
// Write ANSI escape code directly to builder (avoids temp allocation)
write_ansi_color :: proc(b: ^strings.Builder, c: Color, is_bg: bool) {
	switch v in c {
	case Basic_Color:
		if is_bg {
			strings.write_string(b, ANSI_BG_CODES[v])
		} else {
			strings.write_string(b, ANSI_FG_CODES[v])
		}

	case ANSI256:
		// FG: \x1b[38;5;Nm  BG: \x1b[48;5;Nm
		code := is_bg ? 48 : 38
		fmt.sbprintf(b, "\x1b[%d;5;%dm", code, int(v))

	case RGB:
		// FG: \x1b[38;2;R;G;Bm  BG: \x1b[48;2;R;G;Bm
		code := is_bg ? 48 : 38
		fmt.sbprintf(b, "\x1b[%d;2;%d;%d;%dm", code, v.r, v.g, v.b)
	}
}

// Deprecated helper (kept for compatibility if needed, but inefficient)
color_to_ansi :: proc(c: Color, is_bg: bool) -> string {
	b := strings.builder_make(context.temp_allocator)
	write_ansi_color(&b, c, is_bg)
	return strings.to_string(b)
}


// Lookup tables for ANSI color codes (Basic)
ANSI_FG_CODES := [Basic_Color]string {
	.Reset         = "\x1b[0m",
	.Black         = "\x1b[30m",
	.Red           = "\x1b[31m",
	.Green         = "\x1b[32m",
	.Yellow        = "\x1b[33m",
	.Blue          = "\x1b[34m",
	.Magenta       = "\x1b[35m",
	.Cyan          = "\x1b[36m",
	.White         = "\x1b[37m",
	.BrightBlack   = "\x1b[90m",
	.BrightRed     = "\x1b[91m",
	.BrightGreen   = "\x1b[92m",
	.BrightYellow  = "\x1b[93m",
	.BrightBlue    = "\x1b[94m",
	.BrightMagenta = "\x1b[95m",
	.BrightCyan    = "\x1b[96m",
	.BrightWhite   = "\x1b[97m",
}

ANSI_BG_CODES := [Basic_Color]string {
	.Reset         = "\x1b[0m",
	.Black         = "\x1b[40m",
	.Red           = "\x1b[41m",
	.Green         = "\x1b[42m",
	.Yellow        = "\x1b[43m",
	.Blue          = "\x1b[44m",
	.Magenta       = "\x1b[45m",
	.Cyan          = "\x1b[46m",
	.White         = "\x1b[47m",
	.BrightBlack   = "\x1b[100m",
	.BrightRed     = "\x1b[101m",
	.BrightGreen   = "\x1b[102m",
	.BrightYellow  = "\x1b[103m",
	.BrightBlue    = "\x1b[104m",
	.BrightMagenta = "\x1b[105m",
	.BrightCyan    = "\x1b[106m",
	.BrightWhite   = "\x1b[107m",
}
