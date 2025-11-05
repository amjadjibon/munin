package munin

import "core:testing"

// ============================================================
// COLORS TESTS - ANSI color code generation
// ============================================================

// ============================================================
// COLOR ENUM TESTS
// ============================================================

@(test)
test_color_enum_values :: proc(t: ^testing.T) {
	// Test that all color enum values are distinct
	testing.expect(t, Color.Reset != Color.Black, "Colors should be distinct")
	testing.expect(t, Color.Red != Color.Green, "Colors should be distinct")
	testing.expect(t, Color.Blue != Color.Yellow, "Colors should be distinct")
	testing.expect(t, Color.Magenta != Color.Cyan, "Colors should be distinct")
	testing.expect(t, Color.White != Color.BrightBlack, "Colors should be distinct")
}

@(test)
test_color_bright_variants :: proc(t: ^testing.T) {
	// Test that bright colors are distinct from normal colors
	testing.expect(t, Color.Red != Color.BrightRed, "Bright variant should differ")
	testing.expect(t, Color.Green != Color.BrightGreen, "Bright variant should differ")
	testing.expect(t, Color.Blue != Color.BrightBlue, "Bright variant should differ")
	testing.expect(t, Color.Yellow != Color.BrightYellow, "Bright variant should differ")
	testing.expect(t, Color.Magenta != Color.BrightMagenta, "Bright variant should differ")
	testing.expect(t, Color.Cyan != Color.BrightCyan, "Bright variant should differ")
	testing.expect(t, Color.White != Color.BrightWhite, "Bright variant should differ")
}

@(test)
test_color_gray_alias :: proc(t: ^testing.T) {
	// Gray should be the same as BrightBlack
	testing.expect_value(t, Color.Gray, Color.BrightBlack)
}

// ============================================================
// ANSI FOREGROUND CODE TESTS
// ============================================================

@(test)
test_ansi_fg_reset :: proc(t: ^testing.T) {
	testing.expect_value(t, ANSI_FG_CODES[Color.Reset], "\x1b[0m")
}

@(test)
test_ansi_fg_basic_colors :: proc(t: ^testing.T) {
	testing.expect_value(t, ANSI_FG_CODES[Color.Black], "\x1b[30m")
	testing.expect_value(t, ANSI_FG_CODES[Color.Red], "\x1b[31m")
	testing.expect_value(t, ANSI_FG_CODES[Color.Green], "\x1b[32m")
	testing.expect_value(t, ANSI_FG_CODES[Color.Yellow], "\x1b[33m")
	testing.expect_value(t, ANSI_FG_CODES[Color.Blue], "\x1b[34m")
	testing.expect_value(t, ANSI_FG_CODES[Color.Magenta], "\x1b[35m")
	testing.expect_value(t, ANSI_FG_CODES[Color.Cyan], "\x1b[36m")
	testing.expect_value(t, ANSI_FG_CODES[Color.White], "\x1b[37m")
}

@(test)
test_ansi_fg_bright_colors :: proc(t: ^testing.T) {
	testing.expect_value(t, ANSI_FG_CODES[Color.BrightBlack], "\x1b[90m")
	testing.expect_value(t, ANSI_FG_CODES[Color.BrightRed], "\x1b[91m")
	testing.expect_value(t, ANSI_FG_CODES[Color.BrightGreen], "\x1b[92m")
	testing.expect_value(t, ANSI_FG_CODES[Color.BrightYellow], "\x1b[93m")
	testing.expect_value(t, ANSI_FG_CODES[Color.BrightBlue], "\x1b[94m")
	testing.expect_value(t, ANSI_FG_CODES[Color.BrightMagenta], "\x1b[95m")
	testing.expect_value(t, ANSI_FG_CODES[Color.BrightCyan], "\x1b[96m")
	testing.expect_value(t, ANSI_FG_CODES[Color.BrightWhite], "\x1b[97m")
}

@(test)
test_ansi_fg_gray_alias :: proc(t: ^testing.T) {
	// Gray should produce same code as BrightBlack
	testing.expect_value(t, ANSI_FG_CODES[Color.Gray], "\x1b[90m")
	testing.expect_value(t, ANSI_FG_CODES[Color.Gray], ANSI_FG_CODES[Color.BrightBlack])
}

// ============================================================
// ANSI BACKGROUND CODE TESTS
// ============================================================

@(test)
test_ansi_bg_reset :: proc(t: ^testing.T) {
	testing.expect_value(t, ANSI_BG_CODES[Color.Reset], "\x1b[0m")
}

@(test)
test_ansi_bg_basic_colors :: proc(t: ^testing.T) {
	testing.expect_value(t, ANSI_BG_CODES[Color.Black], "\x1b[40m")
	testing.expect_value(t, ANSI_BG_CODES[Color.Red], "\x1b[41m")
	testing.expect_value(t, ANSI_BG_CODES[Color.Green], "\x1b[42m")
	testing.expect_value(t, ANSI_BG_CODES[Color.Yellow], "\x1b[43m")
	testing.expect_value(t, ANSI_BG_CODES[Color.Blue], "\x1b[44m")
	testing.expect_value(t, ANSI_BG_CODES[Color.Magenta], "\x1b[45m")
	testing.expect_value(t, ANSI_BG_CODES[Color.Cyan], "\x1b[46m")
	testing.expect_value(t, ANSI_BG_CODES[Color.White], "\x1b[47m")
}

@(test)
test_ansi_bg_bright_colors :: proc(t: ^testing.T) {
	testing.expect_value(t, ANSI_BG_CODES[Color.BrightBlack], "\x1b[100m")
	testing.expect_value(t, ANSI_BG_CODES[Color.BrightRed], "\x1b[101m")
	testing.expect_value(t, ANSI_BG_CODES[Color.BrightGreen], "\x1b[102m")
	testing.expect_value(t, ANSI_BG_CODES[Color.BrightYellow], "\x1b[103m")
	testing.expect_value(t, ANSI_BG_CODES[Color.BrightBlue], "\x1b[104m")
	testing.expect_value(t, ANSI_BG_CODES[Color.BrightMagenta], "\x1b[105m")
	testing.expect_value(t, ANSI_BG_CODES[Color.BrightCyan], "\x1b[106m")
	testing.expect_value(t, ANSI_BG_CODES[Color.BrightWhite], "\x1b[107m")
}

@(test)
test_ansi_bg_gray_alias :: proc(t: ^testing.T) {
	// Gray should produce same code as BrightBlack
	testing.expect_value(t, ANSI_BG_CODES[Color.Gray], "\x1b[100m")
	testing.expect_value(t, ANSI_BG_CODES[Color.Gray], ANSI_BG_CODES[Color.BrightBlack])
}

// ============================================================
// CODE FORMAT TESTS
// ============================================================

@(test)
test_ansi_code_format_consistency :: proc(t: ^testing.T) {
	// All codes should start with ESC [ and end with m (except Reset which is \x1b[0m)
	for color in Color {
		fg_code := ANSI_FG_CODES[color]
		bg_code := ANSI_BG_CODES[color]

		// Check foreground
		testing.expect(t, len(fg_code) >= 4, "FG code should have minimum length")
		testing.expect_value(t, fg_code[0], byte(0x1b), "Should start with ESC")
		testing.expect_value(t, fg_code[1], byte('['), "Should have [")
		testing.expect_value(t, fg_code[len(fg_code)-1], byte('m'), "Should end with m")

		// Check background
		testing.expect(t, len(bg_code) >= 4, "BG code should have minimum length")
		testing.expect_value(t, bg_code[0], byte(0x1b), "Should start with ESC")
		testing.expect_value(t, bg_code[1], byte('['), "Should have [")
		testing.expect_value(t, bg_code[len(bg_code)-1], byte('m'), "Should end with m")
	}
}

@(test)
test_ansi_fg_bg_different :: proc(t: ^testing.T) {
	// Foreground and background codes should be different for the same color
	for color in Color {
		if color == .Reset {
			// Reset is the same for both
			continue
		}

		fg := ANSI_FG_CODES[color]
		bg := ANSI_BG_CODES[color]

		testing.expect(t, fg != bg, "FG and BG codes should differ")
	}
}

// ============================================================
// ANSI CODE NUMBER TESTS
// ============================================================

@(test)
test_ansi_fg_number_range :: proc(t: ^testing.T) {
	// Standard colors: 30-37
	// Bright colors: 90-97
	// These are implicit in the code strings, but we verify they exist

	import "core:strings"

	// Standard colors should have codes in 30-37 range
	testing.expect(t, strings.contains(ANSI_FG_CODES[Color.Black], "30"), "Black should be 30")
	testing.expect(t, strings.contains(ANSI_FG_CODES[Color.Red], "31"), "Red should be 31")
	testing.expect(t, strings.contains(ANSI_FG_CODES[Color.Green], "32"), "Green should be 32")
	testing.expect(t, strings.contains(ANSI_FG_CODES[Color.Yellow], "33"), "Yellow should be 33")
	testing.expect(t, strings.contains(ANSI_FG_CODES[Color.Blue], "34"), "Blue should be 34")
	testing.expect(t, strings.contains(ANSI_FG_CODES[Color.Magenta], "35"), "Magenta should be 35")
	testing.expect(t, strings.contains(ANSI_FG_CODES[Color.Cyan], "36"), "Cyan should be 36")
	testing.expect(t, strings.contains(ANSI_FG_CODES[Color.White], "37"), "White should be 37")

	// Bright colors should have codes in 90-97 range
	testing.expect(t, strings.contains(ANSI_FG_CODES[Color.BrightBlack], "90"), "BrightBlack should be 90")
	testing.expect(t, strings.contains(ANSI_FG_CODES[Color.BrightRed], "91"), "BrightRed should be 91")
	testing.expect(t, strings.contains(ANSI_FG_CODES[Color.BrightGreen], "92"), "BrightGreen should be 92")
	testing.expect(t, strings.contains(ANSI_FG_CODES[Color.BrightYellow], "93"), "BrightYellow should be 93")
	testing.expect(t, strings.contains(ANSI_FG_CODES[Color.BrightBlue], "94"), "BrightBlue should be 94")
	testing.expect(t, strings.contains(ANSI_FG_CODES[Color.BrightMagenta], "95"), "BrightMagenta should be 95")
	testing.expect(t, strings.contains(ANSI_FG_CODES[Color.BrightCyan], "96"), "BrightCyan should be 96")
	testing.expect(t, strings.contains(ANSI_FG_CODES[Color.BrightWhite], "97"), "BrightWhite should be 97")
}

@(test)
test_ansi_bg_number_range :: proc(t: ^testing.T) {
	// Standard BG colors: 40-47
	// Bright BG colors: 100-107

	import "core:strings"

	// Standard colors
	testing.expect(t, strings.contains(ANSI_BG_CODES[Color.Black], "40"), "Black BG should be 40")
	testing.expect(t, strings.contains(ANSI_BG_CODES[Color.Red], "41"), "Red BG should be 41")
	testing.expect(t, strings.contains(ANSI_BG_CODES[Color.Green], "42"), "Green BG should be 42")
	testing.expect(t, strings.contains(ANSI_BG_CODES[Color.Yellow], "43"), "Yellow BG should be 43")
	testing.expect(t, strings.contains(ANSI_BG_CODES[Color.Blue], "44"), "Blue BG should be 44")
	testing.expect(t, strings.contains(ANSI_BG_CODES[Color.Magenta], "45"), "Magenta BG should be 45")
	testing.expect(t, strings.contains(ANSI_BG_CODES[Color.Cyan], "46"), "Cyan BG should be 46")
	testing.expect(t, strings.contains(ANSI_BG_CODES[Color.White], "47"), "White BG should be 47")

	// Bright colors
	testing.expect(t, strings.contains(ANSI_BG_CODES[Color.BrightBlack], "100"), "BrightBlack BG should be 100")
	testing.expect(t, strings.contains(ANSI_BG_CODES[Color.BrightRed], "101"), "BrightRed BG should be 101")
	testing.expect(t, strings.contains(ANSI_BG_CODES[Color.BrightGreen], "102"), "BrightGreen BG should be 102")
	testing.expect(t, strings.contains(ANSI_BG_CODES[Color.BrightYellow], "103"), "BrightYellow BG should be 103")
	testing.expect(t, strings.contains(ANSI_BG_CODES[Color.BrightBlue], "104"), "BrightBlue BG should be 104")
	testing.expect(t, strings.contains(ANSI_BG_CODES[Color.BrightMagenta], "105"), "BrightMagenta BG should be 105")
	testing.expect(t, strings.contains(ANSI_BG_CODES[Color.BrightCyan], "106"), "BrightCyan BG should be 106")
	testing.expect(t, strings.contains(ANSI_BG_CODES[Color.BrightWhite], "107"), "BrightWhite BG should be 107")
}

// ============================================================
// ARRAY BOUNDS TESTS
// ============================================================

@(test)
test_ansi_code_arrays_complete :: proc(t: ^testing.T) {
	// Verify all colors have entries in both arrays
	for color in Color {
		fg := ANSI_FG_CODES[color]
		bg := ANSI_BG_CODES[color]

		testing.expect(t, len(fg) > 0, "FG code should not be empty")
		testing.expect(t, len(bg) > 0, "BG code should not be empty")
	}
}
