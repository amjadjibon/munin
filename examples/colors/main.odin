package main

import "../../munin"
import "core:fmt"

main :: proc() {
	fmt.println("Advanced Color Support Demo")
	fmt.println("===========================")

	// 1. Hex Colors (TrueColor)
	s1 := munin.new_style()
	s1 = munin.style_foreground_str(s1, "#FF00FF") // Magenta
	s1 = munin.style_bold(s1)
	out_s1 := munin.style_render(s1, "This is Hex #FF00FF (Magenta)")
	defer delete(out_s1)
	fmt.println(out_s1)

	s2 := munin.new_style()
	s2 = munin.style_foreground_str(s2, "#00FF00") // Green
	s2 = munin.style_background_str(s2, "#333333") // Dark Grey BG
	s2 = munin.style_padding_all(s2, 1)
	out_s2 := munin.style_render(s2, "Hex Green on Dark Grey")
	defer delete(out_s2)
	fmt.println(out_s2)

	// 2. ANSI 256 Colors
	s3 := munin.new_style()
	s3 = munin.style_foreground_str(s3, "214") // Orange
	out_s3 := munin.style_render(s3, "This is ANSI 256 Color 214 (Orange)")
	defer delete(out_s3)
	fmt.println(out_s3)

	s4 := munin.new_style()
	s4 = munin.style_foreground(s4, munin.ANSI256(51)) // Cyan
	s4 = munin.style_border(s4, munin.Border_Rounded)
	s4 = munin.style_border_foreground_str(s4, "#FF5555") // Hex Border
	out_s4 := munin.style_render(s4, "ANSI 256 Text with Hex Border")
	defer delete(out_s4)
	fmt.println(out_s4)

	// 3. Short Hex
	s5 := munin.new_style()
	s5 = munin.style_foreground_str(s5, "#F00") // Red
	out_s5 := munin.style_render(s5, "Short Hex #F00 (Red)")
	defer delete(out_s5)
	fmt.println(out_s5)
}
