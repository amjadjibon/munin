package main

import "../../munin"
import "core:fmt"
import "core:strings"

main :: proc() {
	// 1. Basic Text Styling
	s1 := munin.new_style()
	s1 = munin.style_foreground(s1, .BrightGreen)
	s1 = munin.style_bold(s1)
	s1 = munin.style_padding_all(s1, 1) // Padding 1

	output1 := munin.style_render(s1, "Hello, Styled World!")
	defer delete(output1)
	fmt.println(output1)

	// 2. Borders and Margins
	s2 := munin.new_style()
	s2 = munin.style_border(s2, munin.Border_Rounded)
	s2 = munin.style_border_foreground(s2, .BrightCyan)
	s2 = munin.style_padding_v_h(s2, 1, 2)
	s2 = munin.style_foreground(s2, .White)

	output2 := munin.style_render(s2, "I have a rounded border\nand padding!")
	defer delete(output2)
	fmt.println(output2)

	// 3. Composition (Manual for now)
	s3 := munin.new_style()
	s3 = munin.style_background(s3, .Blue)
	s3 = munin.style_foreground(s3, .White)
	s3 = munin.style_bold(s3)
	s3 = munin.style_padding_all(s3, 2)
	s3 = munin.style_margin_all(s3, 1)
	s3 = munin.style_border(s3, munin.Border_Double)
	s3 = munin.style_border_foreground(s3, .Yellow)

	output3 := munin.style_render(s3, "ABSOLUTE\nPOWER")
	defer delete(output3)
	fmt.println(output3)

	// 4. Layout (Horizontal Join)
	left_col := munin.style_render(s2, "Left Column\nLine 2")
	defer delete(left_col)
	right_col := munin.style_render(s2, "Right Column\nLine 2\nLine 3")
	defer delete(right_col)

	joined := munin.join_horizontal(.Center, {left_col, right_col}, 2)
	defer delete(joined)
	fmt.println("\nJoined Layout:")
	fmt.println(joined)

	// 5. Layout (Vertical Join)
	top := munin.style_render(s1, "Top Header")
	defer delete(top)
	bottom := munin.style_render(s3, "Bottom Content")
	defer delete(bottom)

	v_joined := munin.join_vertical(.Center, {top, bottom}, 1)
	defer delete(v_joined)
	fmt.println("\nVertical Layout:")
	fmt.println(v_joined)
}
