package components

import munin ".."
import "core:fmt"
import "core:strings"

// ============================================================
// LIST COMPONENT
// ============================================================

List_Style :: enum {
	Bullet,
	Number,
	Arrow,
	Checkbox,
	Custom,
}

List_Item :: struct {
	text:    string,
	checked: bool, // For checkbox style
	color:   munin.Color,
}

// Draw a list with various styles
draw_list :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	items: []List_Item,
	selected: int = -1,
	style: List_Style = .Bullet,
	custom_marker: string = "",
	selected_color: munin.Color = munin.Basic_Color.BrightYellow,
	indent: int = 2,
	// See draw_table: item text is sanitized unless you opt out.
	sanitize: bool = true,
) {
	for item, i in items {
		current_y := pos.y + i
		is_selected := i == selected

		// Selection indicator
		if is_selected {
			munin.print_at(buf, {pos.x, current_y}, "►", selected_color)
		}

		marker_x := pos.x + (is_selected ? 2 : 0)

		// Draw marker based on style
		marker := ""
		// NOTE: written as an if rather than a ternary - a ternary whose
		// branches are a union value and a constant conversion to that union
		// makes the Odin backend emit a mistyped LLVM PHI node, which fails
		// code generation for this whole procedure.
		marker_color := munin.Color(munin.Basic_Color.White)
		if !munin.is_color_reset(item.color) {
			marker_color = item.color
		}

		switch style {
		case .Bullet:
			marker = "•"
		case .Number:
			marker = fmt.tprintf("%d.", i + 1)
		case .Arrow:
			marker = "→"
		case .Checkbox:
			marker = item.checked ? "[✓]" : "[ ]"
			marker_color = item.checked ? munin.Basic_Color.BrightGreen : munin.Basic_Color.White
		case .Custom:
			marker = custom_marker
		}

		munin.print_at(buf, {marker_x, current_y}, marker, marker_color)

		// Draw text with color and selection highlight
		text_x := marker_x + len(marker) + 1
		text_color := munin.Color(munin.Basic_Color.White)
		if !munin.is_color_reset(item.color) {
			text_color = item.color
		}

		if is_selected {
			munin.set_bold(buf)
			text_color = selected_color
		}

		munin.print_at(buf, {text_x, current_y}, display_text(item.text, sanitize), text_color)
		munin.reset_style(buf)
	}
}

// Draw a scrollable list with viewport
draw_list_scrollable :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	visible_height: int,
	items: []List_Item,
	selected: int,
	scroll_offset: int,
	style: List_Style = .Bullet,
	sanitize: bool = true,
) {
	if visible_height <= 0 || len(items) == 0 {
		return
	}

	// Calculate visible range
	start := clamp(scroll_offset, 0, len(items))
	end := min(start + visible_height, len(items))

	// Draw visible items
	visible_items := items[start:end]
	adjusted_selected := selected - start

	draw_list(buf, pos, visible_items, adjusted_selected, style, sanitize = sanitize)

	// Draw scroll indicators
	if start > 0 && pos.y > 0 {
		munin.print_at(buf, {pos.x + 20, pos.y - 1}, "▲ More above", .BrightBlue)
	}
	if end < len(items) {
		munin.print_at(buf, {pos.x + 20, pos.y + visible_height}, "▼ More below", .BrightBlue)
	}
}
