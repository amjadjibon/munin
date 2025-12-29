package munin

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
