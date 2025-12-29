package components

import munin ".."
import "core:strings"

// ============================================================
// SPINNER COMPONENT
// ============================================================

Spinner_Style :: enum {
	Dots,
	Line,
	Arrow,
	Circle,
	Box,
	Star,
	Moon,
	Clock,
}

Spinner_Direction :: enum {
	Forward,
	Reverse,
}

SPINNER_FRAMES_DOTS := [8]string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧"}
SPINNER_FRAMES_LINE := [4]string{"-", "\\", "|", "/"}
SPINNER_FRAMES_ARROW := [8]string{"←", "↖", "↑", "↗", "→", "↘", "↓", "↙"}
SPINNER_FRAMES_CIRCLE := [4]string{"◐", "◓", "◑", "◒"}
SPINNER_FRAMES_BOX := [4]string{"◰", "◳", "◲", "◱"}
SPINNER_FRAMES_STAR := [6]string{"✶", "✸", "✹", "✺", "✹", "✸"}
SPINNER_FRAMES_MOON := [8]string{"🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"}
SPINNER_FRAMES_CLOCK := [12]string {
	"🕐",
	"🕑",
	"🕒",
	"🕓",
	"🕔",
	"🕕",
	"🕖",
	"🕗",
	"🕘",
	"🕙",
	"🕚",
	"🕛",
}

// Draw a spinner at position
draw_spinner :: proc(
	buf: ^strings.Builder,
	pos: munin.Vec2i,
	frame: int,
	style: Spinner_Style = .Dots,
	color: munin.Color = .BrightCyan,
	label: string = "",
	direction: Spinner_Direction = .Forward,
) {
	frames_str := ""
	frame_count := 0
	frame_index := frame

	switch style {
	case .Dots:
		frame_count = len(SPINNER_FRAMES_DOTS)
		frame_index = calculate_frame_index(frame, frame_count, direction)
		frames_str = SPINNER_FRAMES_DOTS[frame_index]
	case .Line:
		frame_count = len(SPINNER_FRAMES_LINE)
		frame_index = calculate_frame_index(frame, frame_count, direction)
		frames_str = SPINNER_FRAMES_LINE[frame_index]
	case .Arrow:
		frame_count = len(SPINNER_FRAMES_ARROW)
		frame_index = calculate_frame_index(frame, frame_count, direction)
		frames_str = SPINNER_FRAMES_ARROW[frame_index]
	case .Circle:
		frame_count = len(SPINNER_FRAMES_CIRCLE)
		frame_index = calculate_frame_index(frame, frame_count, direction)
		frames_str = SPINNER_FRAMES_CIRCLE[frame_index]
	case .Box:
		frame_count = len(SPINNER_FRAMES_BOX)
		frame_index = calculate_frame_index(frame, frame_count, direction)
		frames_str = SPINNER_FRAMES_BOX[frame_index]
	case .Star:
		frame_count = len(SPINNER_FRAMES_STAR)
		frame_index = calculate_frame_index(frame, frame_count, direction)
		frames_str = SPINNER_FRAMES_STAR[frame_index]
	case .Moon:
		frame_count = len(SPINNER_FRAMES_MOON)
		frame_index = calculate_frame_index(frame, frame_count, direction)
		frames_str = SPINNER_FRAMES_MOON[frame_index]
	case .Clock:
		frame_count = len(SPINNER_FRAMES_CLOCK)
		frame_index = calculate_frame_index(frame, frame_count, direction)
		frames_str = SPINNER_FRAMES_CLOCK[frame_index]
	}

	munin.move_cursor(buf, pos)
	munin.set_color(buf, color)
	strings.write_string(buf, frames_str)
	munin.reset_style(buf)

	// Draw label if provided
	if len(label) > 0 {
		munin.print_at(buf, pos + {2, 0}, label, .White)
	}
}

// Calculate frame index based on direction
calculate_frame_index :: proc(frame: int, frame_count: int, direction: Spinner_Direction) -> int {
	if direction == .Reverse {
		// Reverse direction: count backwards
		return (frame_count - (frame % frame_count)) % frame_count
	}
	// Forward direction: normal
	return frame % frame_count
}

// Get the number of frames for a spinner style
get_spinner_frame_count :: proc(style: Spinner_Style) -> int {
	switch style {
	case .Dots:
		return len(SPINNER_FRAMES_DOTS)
	case .Line:
		return len(SPINNER_FRAMES_LINE)
	case .Arrow:
		return len(SPINNER_FRAMES_ARROW)
	case .Circle:
		return len(SPINNER_FRAMES_CIRCLE)
	case .Box:
		return len(SPINNER_FRAMES_BOX)
	case .Star:
		return len(SPINNER_FRAMES_STAR)
	case .Moon:
		return len(SPINNER_FRAMES_MOON)
	case .Clock:
		return len(SPINNER_FRAMES_CLOCK)
	}
	return 0
}
