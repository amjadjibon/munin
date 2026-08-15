package munin

import "core:strings"
import "core:testing"

@(test)
test_named_colors :: proc(t: ^testing.T) {
	c := color_from_string("red")
	if val, ok := c.?; ok {
		if basic, ok := val.(Basic_Color); ok {
			testing.expect_value(t, basic, Basic_Color.Red)
		} else {
			testing.expect(t, false, "Expected Basic_Color")
		}
	} else {
		testing.expect(t, false, "Expected non-nil color")
	}

	c = color_from_string("BLUE")
	if val, ok := c.?; ok {
		if basic, ok := val.(Basic_Color); ok {
			testing.expect_value(t, basic, Basic_Color.Blue)
		} else {
			testing.expect(t, false, "Expected Basic_Color")
		}
	} else {
		testing.expect(t, false, "Expected non-nil color")
	}

	c = color_from_string("BrightGreen")
	if val, ok := c.?; ok {
		if basic, ok := val.(Basic_Color); ok {
			testing.expect_value(t, basic, Basic_Color.BrightGreen)
		} else {
			testing.expect(t, false, "Expected Basic_Color")
		}
	} else {
		testing.expect(t, false, "Expected non-nil color")
	}

	c = color_from_string("unknown")
	testing.expect(t, c == nil)
}

@(test)
test_hex_colors :: proc(t: ^testing.T) {
	c := color_from_string("#ff0000")
	if val, ok := c.?; ok {
		if rgb, ok := val.(RGB); ok {
			testing.expect_value(t, rgb.r, 255)
			testing.expect_value(t, rgb.g, 0)
			testing.expect_value(t, rgb.b, 0)
		} else {
			testing.expect(t, false, "Expected RGB")
		}
	} else {
		testing.expect(t, false, "Expected non-nil color")
	}
}

// ============================================================
// COLOR PARSING - remaining forms and edge cases
// ============================================================

@(test)
test_color_from_string_short_hex :: proc(t: ^testing.T) {
	val, ok := color_from_string("#f0a").?
	testing.expect(t, ok, "Should parse 3-digit hex")
	testing.expect_value(t, val, Color(RGB{255, 0, 170}))
}

@(test)
test_color_from_string_ansi256 :: proc(t: ^testing.T) {
	val, ok := color_from_string("42").?
	testing.expect(t, ok, "Should parse a 256-color index")
	testing.expect_value(t, val, Color(ANSI256(42)))

	lo, lo_ok := color_from_string("0").?
	testing.expect(t, lo_ok, "0 is a valid index")
	testing.expect_value(t, lo, Color(ANSI256(0)))

	hi, hi_ok := color_from_string("255").?
	testing.expect(t, hi_ok, "255 is a valid index")
	testing.expect_value(t, hi, Color(ANSI256(255)))
}

@(test)
test_color_from_string_rejects_out_of_range :: proc(t: ^testing.T) {
	testing.expect(t, color_from_string("256") == nil, "256 is out of range")
	testing.expect(t, color_from_string("-1") == nil, "Negative is out of range")
}

@(test)
test_color_from_string_rejects_malformed :: proc(t: ^testing.T) {
	testing.expect(t, color_from_string("") == nil, "Empty string")
	testing.expect(t, color_from_string("#") == nil, "Bare hash")
	testing.expect(t, color_from_string("#ff") == nil, "Two hex digits")
	testing.expect(t, color_from_string("#gggggg") == nil, "Non-hex digits")
	testing.expect(t, color_from_string("#ff00ff00") == nil, "Too many hex digits")
}

@(test)
test_color_from_string_gray_alias :: proc(t: ^testing.T) {
	val, ok := color_from_string("gray").?
	testing.expect(t, ok, "gray should be an alias")
	testing.expect_value(t, val, Color(Basic_Color.BrightBlack))
}

@(test)
test_color_from_string_all_basic_names :: proc(t: ^testing.T) {
	names := []string {
		"black",
		"red",
		"green",
		"yellow",
		"blue",
		"magenta",
		"cyan",
		"white",
		"brightblack",
		"brightred",
		"brightgreen",
		"brightyellow",
		"brightblue",
		"brightmagenta",
		"brightcyan",
		"brightwhite",
	}
	for name in names {
		val, ok := color_from_string(name).?
		testing.expectf(t, ok, "%s should parse", name)
		if ok {
			_, is_basic := val.(Basic_Color)
			testing.expectf(t, is_basic, "%s should be a Basic_Color", name)
		}
	}
}

// ============================================================
// ANSI EMISSION
// ============================================================

@(test)
test_write_ansi_color_basic :: proc(t: ^testing.T) {
	b := strings.builder_make()
	defer strings.builder_destroy(&b)

	write_ansi_color(&b, Basic_Color.Red, false)
	testing.expect_value(t, strings.to_string(b), "\x1b[31m")

	strings.builder_reset(&b)
	write_ansi_color(&b, Basic_Color.Red, true)
	testing.expect_value(t, strings.to_string(b), "\x1b[41m")
}

@(test)
test_write_ansi_color_rgb :: proc(t: ^testing.T) {
	b := strings.builder_make()
	defer strings.builder_destroy(&b)

	write_ansi_color(&b, RGB{10, 20, 30}, false)
	testing.expect_value(t, strings.to_string(b), "\x1b[38;2;10;20;30m")

	strings.builder_reset(&b)
	write_ansi_color(&b, RGB{10, 20, 30}, true)
	testing.expect_value(t, strings.to_string(b), "\x1b[48;2;10;20;30m")
}

@(test)
test_write_ansi_color_ansi256 :: proc(t: ^testing.T) {
	b := strings.builder_make()
	defer strings.builder_destroy(&b)

	write_ansi_color(&b, ANSI256(200), false)
	testing.expect_value(t, strings.to_string(b), "\x1b[38;5;200m")
}

@(test)
test_write_ansi_color_nil_writes_nothing :: proc(t: ^testing.T) {
	b := strings.builder_make()
	defer strings.builder_destroy(&b)

	c: Color
	write_ansi_color(&b, c, false)
	testing.expect_value(t, strings.builder_len(b), 0)
}

@(test)
test_color_to_ansi_matches_write_ansi_color :: proc(t: ^testing.T) {
	b := strings.builder_make()
	defer strings.builder_destroy(&b)

	write_ansi_color(&b, Basic_Color.BrightCyan, false)
	testing.expect_value(t, color_to_ansi(Basic_Color.BrightCyan, false), strings.to_string(b))
	free_all(context.temp_allocator)
}

@(test)
test_is_color_reset :: proc(t: ^testing.T) {
	testing.expect(t, is_color_reset(Basic_Color.Reset), "Reset is reset")
	testing.expect(t, !is_color_reset(Basic_Color.Red), "Red is not reset")
	testing.expect(t, !is_color_reset(RGB{0, 0, 0}), "Black RGB is not reset")
	testing.expect(t, !is_color_reset(ANSI256(0)), "ANSI256 0 is not reset")
}

@(test)
test_ansi_code_tables_are_complete :: proc(t: ^testing.T) {
	for c in Basic_Color {
		testing.expectf(t, len(ANSI_FG_CODES[c]) > 0, "Missing fg code for %v", c)
		testing.expectf(t, len(ANSI_BG_CODES[c]) > 0, "Missing bg code for %v", c)
	}
}
