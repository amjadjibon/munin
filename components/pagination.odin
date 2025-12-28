package components

import munin "../munin"
import "core:fmt"
import "core:strings"

// ============================================================
// PAGINATION COMPONENT
// ============================================================

Pagination_Style :: enum {
	Numbers, // 1 2 3 4 5
	Arrows, // ← 1/5 →
	Dots, // • • ○ • •
	Compact, // Page 3 of 10
}

// Draw pagination controls
draw_pagination :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	current_page: int,
	total_pages: int,
	style: Pagination_Style = .Numbers,
	max_visible: int = 7,
	active_color: munin.Color = munin.Basic_Color.BrightCyan,
	normal_color: munin.Color = munin.Basic_Color.White,
	disabled_color: munin.Color = munin.Basic_Color.BrightBlue,
) {
	if total_pages <= 0 {
		return
	}

	x := pos.x
	y := pos.y
	current_x := x

	switch style {
	case .Numbers:
		// Previous arrow
		prev_color := current_page > 1 ? normal_color : disabled_color
		munin.print_at(buf, {current_x, y}, "←", prev_color)
		current_x += 2

		// Calculate visible page range
		start_page := 1
		end_page := total_pages

		if total_pages > max_visible {
			half := max_visible / 2
			start_page = max(1, current_page - half)
			end_page = min(total_pages, start_page + max_visible - 1)

			// Adjust if we're at the end
			if end_page == total_pages {
				start_page = max(1, end_page - max_visible + 1)
			}
		}

		// Show first page if not visible
		if start_page > 1 {
			munin.print_at(buf, {current_x, y}, "1", normal_color)
			current_x += 2
			if start_page > 2 {
				munin.print_at(buf, {current_x, y}, "...", disabled_color)
				current_x += 4
			}
		}

		// Draw page numbers
		for page in start_page ..= end_page {
			color := page == current_page ? active_color : normal_color
			if page == current_page {
				munin.set_bold(buf)
			}
			page_str := fmt.tprintf("%d", page)
			munin.print_at(buf, {current_x, y}, page_str, color)
			munin.reset_style(buf)
			current_x += len(page_str) + 1
		}

		// Show last page if not visible
		if end_page < total_pages {
			if end_page < total_pages - 1 {
				munin.print_at(buf, {current_x, y}, "...", disabled_color)
				current_x += 4
			}
			page_str := fmt.tprintf("%d", total_pages)
			munin.print_at(buf, {current_x, y}, page_str, normal_color)
			current_x += len(page_str) + 1
		}

		// Next arrow
		next_color := current_page < total_pages ? normal_color : disabled_color
		munin.print_at(buf, {current_x, y}, "→", next_color)

	case .Arrows:
		// Previous arrow
		prev_color := current_page > 1 ? active_color : disabled_color
		munin.print_at(buf, {current_x, y}, "←", prev_color)
		current_x += 2

		// Page indicator
		page_text := fmt.tprintf("%d/%d", current_page, total_pages)
		munin.print_at(buf, {current_x, y}, page_text, normal_color)
		current_x += len(page_text) + 1

		// Next arrow
		next_color := current_page < total_pages ? active_color : disabled_color
		munin.print_at(buf, {current_x, y}, "→", next_color)

	case .Dots:
		// Show dots for each page
		for page in 1 ..= total_pages {
			dot := page == current_page ? "●" : "○"
			color := page == current_page ? active_color : disabled_color
			munin.print_at(buf, {current_x, y}, dot, color)
			current_x += 2
		}

	case .Compact:
		page_text := fmt.tprintf("Page %d of %d", current_page, total_pages)
		munin.print_at(buf, {current_x, y}, page_text, normal_color)
		current_x += len(page_text) + 2

		// Add navigation hints
		if current_page > 1 {
			munin.print_at(buf, {current_x, y}, "[←Prev]", active_color)
			current_x += 8
		}
		if current_page < total_pages {
			munin.print_at(buf, {current_x, y}, "[Next→]", active_color)
		}
	}
}

// Draw pagination with item count info
draw_pagination_with_info :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	current_page: int,
	total_pages: int,
	items_per_page: int,
	total_items: int,
	style: Pagination_Style = .Numbers,
) {
	// Draw pagination controls
	draw_pagination(
		buf,
		pos,
		current_page,
		total_pages,
		style,
		7,
		munin.Basic_Color.BrightCyan,
		munin.Basic_Color.White,
		munin.Basic_Color.BrightBlue,
	)

	// Draw item info
	start_item := (current_page - 1) * items_per_page + 1
	end_item := min(current_page * items_per_page, total_items)

	info_text := fmt.tprintf("Showing %d-%d of %d items", start_item, end_item, total_items)
	munin.print_at(buf, {pos.x, pos.y + 2}, info_text, munin.Basic_Color.BrightBlue)
}

// Calculate total pages from item count
calculate_pages :: proc(total_items, items_per_page: int) -> int {
	if items_per_page <= 0 {
		return 0
	}
	return (total_items + items_per_page - 1) / items_per_page
}

// Get items for current page
get_page_slice :: proc(items: $T/[]$E, current_page, items_per_page: int) -> T {
	start := (current_page - 1) * items_per_page
	end := min(start + items_per_page, len(items))
	start = clamp(start, 0, len(items))
	end = clamp(end, 0, len(items))
	return items[start:end]
}
