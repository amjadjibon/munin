package munin

import "core:fmt"
import "core:mem"
import "core:strings"
import "core:time"
import "core:unicode/utf8"

// Foreign imports for system calls
when ODIN_OS != .Windows {
	foreign import libc "system:c"
	@(default_calling_convention = "c")
	foreign libc {
		fflush :: proc(stream: rawptr) -> i32 ---
	}
}

// ============================================================
// CORE TYPES
// ============================================================

// Screen mode for the terminal
Screen_Mode :: enum {
	Fullscreen, // Alternative screen buffer (default)
	Inline, // Normal inline mode
}

// Program represents a TUI application
Program :: struct($Model, $Msg: typeid) {
	model:           Model,
	running:         bool,
	screen_mode:     Screen_Mode,
	init:            proc() -> Model,
	update:          proc(msg: Msg, model: Model) -> (Model, bool),
	view:            proc(model: Model, buf: ^strings.Builder),
	subscriptions:   Maybe(proc(model: Model) -> Maybe(Msg)),
	buffer:          strings.Builder,
	allocator:       mem.Allocator,
	last_line_count: int, // Track number of lines rendered (for inline mode)
	clear_on_exit:   bool, // Whether to clear screen on exit
}

// ============================================================
// HELPER FUNCTIONS
// ============================================================

// Strip ANSI escape sequences from a string to get visual content
// Optimized version: avoids allocation if no ANSI codes present
strip_ansi :: proc(s: string) -> string {
	if len(s) == 0 {
		return s
	}

	// Fast path: check if there are any ANSI codes at all
	has_ansi := false
	for i in 0 ..< len(s) {
		if s[i] == 0x1b {
			has_ansi = true
			break
		}
	}

	// If no ANSI codes, return original string (zero allocation)
	if !has_ansi {
		return s
	}

	// Slow path: allocate and strip ANSI codes
	result := make([]byte, len(s), context.temp_allocator)
	result_len := 0
	i := 0

	for i < len(s) {
		// Check for ANSI escape sequence (ESC [ ... m or other control sequences)
		if s[i] == 0x1b {
			// Bounds check once
			if i + 1 >= len(s) {
				// Incomplete escape at end, skip it
				break
			}

			// Skip escape character
			i += 1

			// Handle CSI sequences (ESC [ ...)
			if s[i] == '[' {
				i += 1
				// Skip until we find a letter (typically m, H, J, K, etc.)
				for i < len(s) {
					ch := s[i]
					i += 1
					// Optimized: single comparison using ranges
					if (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') {
						break
					}
				}
			} else if s[i] == ']' {
				// Handle OSC sequences (ESC ] ... BEL or ESC ] ... ST)
				i += 1
				for i < len(s) {
					if s[i] == 0x07 { 	// BEL
						i += 1
						break
					}
					// Check for ST (ESC \) with single bounds check
					if i + 1 < len(s) && s[i] == 0x1b && s[i + 1] == '\\' {
						i += 2
						break
					}
					i += 1
				}
			}
		} else {
			// Regular character - no extra checks needed
			result[result_len] = s[i]
			result_len += 1
			i += 1
		}
	}

	return string(result[:result_len])
}

// Count visual width of a rune (accounts for wide characters like CJK)
// Note: This is a simplified version. Full support would need unicode width tables.
// Optimized with ASCII fast path (most common case)
rune_visual_width :: proc(r: rune) -> int {
	// Fast path: ASCII printable characters (most common case)
	// This covers 95% of typical terminal text
	if r >= 0x20 && r <= 0x7E {
		return 1
	}

	// Fast path: Control characters and DEL
	if r < 0x20 || (r >= 0x7F && r < 0xA0) {
		return 0
	}

	// Slow path: Wide characters (CJK, emoji, etc.)
	// Early exit with single range check before detailed checks
	if r < 0x1100 {
		return 1 // Latin-1 Supplement and other narrow chars
	}

	// Wide characters - check ranges
	if (r >= 0x1100 && r <= 0x115F) ||
	   (r >= 0x2E80 && r <= 0x2EFF) ||
	   (r >= 0x2F00 && r <= 0x2FDF) ||
	   (r >= 0x3000 && r <= 0x303F) ||
	   (r >= 0x3040 && r <= 0x309F) ||
	   (r >= 0x30A0 && r <= 0x30FF) ||
	   (r >= 0x3400 && r <= 0x4DBF) ||
	   (r >= 0x4E00 && r <= 0x9FFF) ||
	   (r >= 0xAC00 && r <= 0xD7AF) ||
	   (r >= 0xF900 && r <= 0xFAFF) ||
	   (r >= 0xFE30 && r <= 0xFE4F) ||
	   (r >= 0xFF00 && r <= 0xFF60) ||
	   (r >= 0xFFE0 && r <= 0xFFE6) ||
	   (r >= 0x1F300 && r <= 0x1F5FF) ||
	   (r >= 0x1F600 && r <= 0x1F64F) ||
	   (r >= 0x1F680 && r <= 0x1F6FF) ||
	   (r >= 0x1F900 && r <= 0x1F9FF) ||
	   (r >= 0x1FA70 && r <= 0x1FAFF) ||
	   (r >= 0x20000 && r <= 0x2FFFF) {
		// Hangul Jamo
		// CJK Radicals
		// Kangxi Radicals
		// CJK Symbols and Punctuation
		// Hiragana
		// Katakana
		// CJK Extension A
		// CJK Unified Ideographs
		// CJK Compatibility
		// Misc Symbols and Pictographs
		// Emoticons
		// Transport and Map Symbols
		// Supplemental Symbols and Pictographs
		// Symbols and Pictographs Extended-A
		// CJK Extension B, C, D, E
		return 2
	}

	// Default: 1 cell
	return 1
}

// Count number of lines in a string (for inline mode rendering)
// This accounts for:
// - ANSI escape sequences (stripped before counting - optimized with fast path)
// - Terminal width for line wrapping (cached to avoid repeated syscalls)
// - Wide characters (CJK, emoji, etc. - optimized with ASCII fast path)
// Optimized: Terminal width is cached, strip_ansi avoids allocation if no ANSI codes
count_lines :: proc(s: string) -> int {
	if len(s) == 0 {
		return 0
	}

	// Get terminal width for wrapping calculation
	// Now cached - only queries system on first call or after resize
	term_width, _, ok := get_window_size()
	if !ok || term_width <= 0 {
		term_width = 80 // Fallback to standard width
	}

	// Strip ANSI codes to get actual visual content
	// Optimized: returns original string if no ANSI codes (zero allocation)
	visual_content := strip_ansi(s)

	line_count := 0
	current_line_width := 0

	for ch in visual_content {
		if ch == '\n' {
			// Explicit newline
			line_count += 1
			current_line_width = 0
		} else {
			// Calculate visual width of this character
			// Optimized: Fast path for ASCII characters (95% of cases)
			char_width := rune_visual_width(ch)
			current_line_width += char_width

			// Check if we've exceeded terminal width (wrapping)
			if current_line_width > term_width {
				line_count += 1
				current_line_width = char_width // Start new line with this character
			}
		}
	}

	// If there's content on the last line (not ending with newline), count it
	if current_line_width > 0 ||
	   (len(visual_content) > 0 && visual_content[len(visual_content) - 1] != '\n') {
		line_count += 1
	}

	return line_count
}

// ============================================================
// PROGRAM CREATION
// ============================================================

// Create a new program without subscriptions
make_program :: proc {
	make_program_without_subs,
	make_program_with_subs,
}

// Internal: Create a new program without subscriptions
make_program_without_subs :: proc(
	init: proc() -> $Model,
	update: proc(msg: $Msg, model: Model) -> (Model, bool),
	view: proc(model: Model, buf: ^strings.Builder),
	allocator := context.allocator,
) -> Program(Model, Msg) {
	buffer :=
		strings.builder_make_len_cap(0, 4096, allocator) or_else strings.builder_make(allocator)
	return Program(Model, Msg) {
		model = init(),
		running = true,
		screen_mode = .Fullscreen,
		init = init,
		update = update,
		view = view,
		subscriptions = nil,
		buffer = buffer,
		allocator = allocator,
	}
}

// Internal: Create a new program with subscriptions
make_program_with_subs :: proc(
	init: proc() -> $Model,
	update: proc(msg: $Msg, model: Model) -> (Model, bool),
	view: proc(model: Model, buf: ^strings.Builder),
	subscriptions: proc(_: Model) -> Maybe(Msg),
	allocator := context.allocator,
) -> Program(Model, Msg) {
	buffer :=
		strings.builder_make_len_cap(0, 4096, allocator) or_else strings.builder_make(allocator)
	return Program(Model, Msg) {
		model = init(),
		running = true,
		screen_mode = .Fullscreen,
		init = init,
		update = update,
		view = view,
		subscriptions = subscriptions,
		buffer = buffer,
		allocator = allocator,
	}
}

// ============================================================
// SCREEN MODE CONTROL
// ============================================================

// Toggle between fullscreen and inline mode
toggle_screen_mode :: proc(program: ^Program($Model, $Msg)) {
	if program.screen_mode == .Fullscreen {
		// Switching from fullscreen to inline
		fmt.print("\x1b[?1049l") // Disable alternative screen
		program.screen_mode = .Inline
		program.last_line_count = 0 // Reset line count for inline mode
	} else {
		// Switching from inline to fullscreen
		// First, clear the inline content by moving up and clearing
		if program.last_line_count > 0 {
			fmt.print("\r")
			fmt.printf("\x1b[%dA", program.last_line_count) // Move up
			fmt.print("\x1b[J") // Clear from cursor down
		}
		fmt.print("\x1b[?1049h") // Enable alternative screen
		program.screen_mode = .Fullscreen
		program.last_line_count = 0 // Reset line count
	}
}

// Set screen mode explicitly
set_screen_mode :: proc(program: ^Program($Model, $Msg), mode: Screen_Mode) {
	if program.screen_mode == mode {
		return
	}
	toggle_screen_mode(program)
}

// ============================================================
// PROGRAM EXECUTION
// ============================================================

// Run the program
run :: proc(
	program: ^Program($Model, $Msg),
	input_handler: proc() -> Maybe(Msg),
	target_fps: i64 = 60,
	initial_mode: Screen_Mode = .Fullscreen,
	clear_on_exit: bool = true,
) {
	// Set initial screen mode and clear on exit option
	program.screen_mode = initial_mode
	program.clear_on_exit = clear_on_exit

	// Set up terminal
	state, ok := set_raw_mode()
	if !ok {
		fmt.eprintln("Failed to set raw mode")
		return
	}
	defer restore_mode(state)
	defer strings.builder_destroy(&program.buffer)

	// Clear screen on exit if requested
	defer {
		if program.clear_on_exit {
			if program.screen_mode == .Inline && program.last_line_count > 0 {
				// In inline mode, clear the rendered content
				fmt.print("\r")
				fmt.printf("\x1b[%dA", program.last_line_count)
				fmt.print("\x1b[J")
			} else if program.screen_mode == .Fullscreen {
				// In fullscreen mode, clear the screen
				fmt.print("\x1b[H\x1b[J")
			}
		}
	}

	// Use the program's allocator for the remainder of execution
	context.allocator = program.allocator

	// Enable alternative screen buffer (only if fullscreen mode)
	if program.screen_mode == .Fullscreen {
		fmt.print("\x1b[?1049h")
		defer fmt.print("\x1b[?1049l")
	}

	// Hide cursor
	fmt.print("\x1b[?25l")
	defer fmt.print("\x1b[?25h")

	// Disable line wrapping to prevent visual artifacts
	fmt.print("\x1b[?7l")
	defer fmt.print("\x1b[?7h")

	// Enable mouse tracking (SGR mode with all events)
	// ?1000 = Enable mouse tracking (button press/release)
	// ?1002 = Enable button event tracking (drag)
	// ?1003 = Enable all motion tracking (including hover)
	// ?1006 = Enable SGR extended mouse mode
	fmt.print("\x1b[?1000h\x1b[?1002h\x1b[?1003h\x1b[?1006h")
	defer fmt.print("\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l")

	// Setup window resize detection
	setup_resize_handler()

	// Track if we need to redraw
	needs_redraw := true

	// Frame timing
	FRAME_TIME := time.Second / time.Duration(target_fps)
	last_frame_time := time.now()

	// Main loop
	for program.running {
		frame_start := time.now()

		// Check for window resize
		if check_window_resized() {
			needs_redraw = true
		}

		// Handle input
		if msg, has_msg := input_handler().?; has_msg {
			new_model, should_quit := program.update(msg, program.model)
			program.model = new_model
			needs_redraw = true // Mark for redraw on input
			if should_quit {
				program.running = false
			}
		}

		// Handle subscriptions (time-based events, etc.)
		if subs, ok := program.subscriptions.?; ok {
			if msg, has_msg := subs(program.model).?; has_msg {
				new_model, should_quit := program.update(msg, program.model)
				program.model = new_model
				needs_redraw = true // Mark for redraw on subscription event
				if should_quit {
					program.running = false
				}
			}
		}

		// Only redraw if needed and enough time has passed
		elapsed := time.diff(last_frame_time, frame_start)
		if needs_redraw && elapsed >= FRAME_TIME {
			// Clear buffer for new frame
			strings.builder_reset(&program.buffer)

			// Render to buffer
			program.view(program.model, &program.buffer)

			// Get output
			output := strings.to_string(program.buffer)

			// Handle inline mode rendering differently
			if program.screen_mode == .Inline {
				// Count lines in new output
				new_line_count := count_lines(output)

				// Move cursor up by previous line count (skip on first render)
				if program.last_line_count > 0 {
					// Move to beginning of line first, then move up
					fmt.print("\r")
					fmt.printf("\x1b[%dA", program.last_line_count)
				}

				// Clear from cursor down and print new output
				fmt.print("\x1b[J")
				fmt.print(output)

				// Update line count
				program.last_line_count = new_line_count
			} else {
				// Fullscreen mode - just print
				fmt.print(output)
			}

			// Force flush to ensure immediate rendering
			when ODIN_OS != .Windows {
				fflush(nil) // flush all streams
			}

			// Reset redraw flag and update last frame time
			needs_redraw = false
			last_frame_time = frame_start
		}

		// Sleep to prevent CPU spinning
		frame_duration := time.diff(frame_start, time.now())
		if frame_duration < FRAME_TIME {
			time.sleep(FRAME_TIME - frame_duration)
		}

		// Reset temp allocator at end of frame
		free_all(context.temp_allocator)
	}
}
