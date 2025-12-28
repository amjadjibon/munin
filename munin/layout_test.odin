package munin

import "core:testing"

@(test)
test_visible_width :: proc(t: ^testing.T) {
	// ASCII
	testing.expect_value(t, get_visible_width("hello"), 5)

	// CJK (Double width)
	testing.expect_value(t, get_visible_width("你好"), 4) // 2 chars * 2 width

	// Mixed
	testing.expect_value(t, get_visible_width("A你好B"), 6) // 1 + 4 + 1

	// Emoji (Double width)
	testing.expect_value(t, get_visible_width("😀"), 2)
}
