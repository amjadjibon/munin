package components

import munin ".."
import "core:strings"
import "core:testing"

@(test)
test_draw_table_does_not_split_utf8_when_cell_matches_width :: proc(t: ^testing.T) {
	buf := strings.builder_make()
	defer strings.builder_destroy(&buf)

	columns := []Table_Column {
		{title = "Title", width = 10, align = .Left},
	}
	rows := [][]string {
		{"abcdefghi…"},
	}

	draw_table(&buf, {0, 0}, columns, rows)
	output := strings.to_string(buf)

	testing.expect(t, strings.contains(output, "abcdefghi…"), "Should preserve full UTF-8 ellipsis")
	testing.expect(t, !strings.contains(output, "�"), "Should not emit replacement characters")
	testing.expect_value(t, munin.get_visible_width("abcdefghi…"), 10)
}
