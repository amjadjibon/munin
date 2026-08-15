package munin

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import "core:time"

// Write directly to stdout. Odin's fmt.print goes straight to the file
// descriptor (there is no libc stream to flush), so the way to cut syscalls
// is to batch a frame into one string and write it once.
@(private)
term_write :: proc(s: string) {
	if len(s) == 0 {
		return
	}
	os.write_string(os.stdout, s)
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
	out_buffer:      strings.Builder, // Frame assembled here so it can be written in one syscall
	last_frame:      strings.Builder, // Previous frame, to skip identical redraws
	allocator:       mem.Allocator,
	last_line_count: int, // Track number of lines rendered (for inline mode)
	clear_on_exit:   bool, // Whether to clear screen on exit
}

// ============================================================
// HELPER FUNCTIONS
// ============================================================

// Strip ANSI escape sequences from a string to get visual content.
// Optimized version: avoids allocation if no ANSI codes present.
//
// The result is either the input string itself or a slice allocated in
// context.temp_allocator, so it is only valid until the arena is reset.
//
// NOTE: this removes escape sequences but leaves other control bytes (BEL,
// CR, ...) in place - it is a measurement helper, not a security boundary.
// Use sanitize_display() before showing untrusted text.
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

	// Slow path: allocate and strip ANSI codes.
	// Sequence boundaries come from skip_escape_sequence(), so CSI, OSC, DCS,
	// SOS, PM and APC forms are all consumed whole - a DCS body used to be
	// emitted as if it were text.
	result := make([]byte, len(s), context.temp_allocator)
	result_len := 0
	i := 0

	for i < len(s) {
		if s[i] == 0x1b {
			i = skip_escape_sequence(s, i)
			continue
		}
		result[result_len] = s[i]
		result_len += 1
		i += 1
	}

	return string(result[:result_len])
}

// Remove everything from s that could make the terminal do something rather
// than display something: escape sequences of every form, plus the C0/C1
// control bytes (newline and tab are kept).
//
// Use this on any text that did not come from your own program - file names,
// log lines, API responses - before writing it to the screen. Without it a
// crafted string can move the cursor, rewrite the window title, or drive OSC
// 52 to write the user's clipboard.
//
// Returns the input string itself when there is nothing to remove (the common
// case, and no allocation), otherwise a string allocated with `allocator`
// (temp arena by default).
sanitize_display :: proc(s: string, allocator := context.temp_allocator) -> string {
	if len(s) == 0 {
		return s
	}

	// Fast path: this sits on the per-frame render path for every piece of
	// text a component draws, so scan before allocating.
	needs_work := false
	for i in 0 ..< len(s) {
		b := s[i]
		if b < 0x20 && b != '\n' && b != '\t' {
			needs_work = true
			break
		}
		if b == 0x7F || b == 0xC2 {
			needs_work = true
			break
		}
	}
	if !needs_work {
		return s
	}

	result := make([]byte, len(s), allocator)
	result_len := 0
	i := 0

	for i < len(s) {
		b := s[i]

		if b == 0x1b {
			i = skip_escape_sequence(s, i)
			continue
		}

		// C0 controls, except the two that are legitimate in display text.
		if b < 0x20 && b != '\n' && b != '\t' {
			i += 1
			continue
		}

		// DEL
		if b == 0x7F {
			i += 1
			continue
		}

		// C1 controls arrive as the two-byte UTF-8 sequences C2 80..C2 9F.
		if b == 0xC2 && i + 1 < len(s) && s[i + 1] >= 0x80 && s[i + 1] <= 0x9F {
			i += 2
			continue
		}

		result[result_len] = b
		result_len += 1
		i += 1
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

	// Wide characters - check ranges.
	// This is the single source of truth for character width in the whole
	// framework; layout.odin's rune_width() forwards here so that line
	// counting and layout can never disagree about the same string.
	if (r >= 0x1100 && r <= 0x115F) || // Hangul Jamo
	   (r >= 0x2329 && r <= 0x232A) || // Angle brackets
	   (r >= 0x2E80 && r <= 0x303F) || // CJK Radicals, Kangxi, CJK Symbols and Punctuation
	   (r >= 0x3040 && r <= 0xA4CF) || // Kana, CJK Extension A, CJK Unified Ideographs, Yi
	   (r >= 0xAC00 && r <= 0xD7A3) || // Hangul Syllables
	   (r >= 0xF900 && r <= 0xFAFF) || // CJK Compatibility Ideographs
	   (r >= 0xFE10 && r <= 0xFE19) || // Vertical Forms
	   (r >= 0xFE30 && r <= 0xFE6F) || // CJK Compatibility Forms, Small Form Variants
	   (r >= 0xFF00 && r <= 0xFF60) || // Fullwidth Forms
	   (r >= 0xFFE0 && r <= 0xFFE6) || // Fullwidth Signs
	   (r >= 0x1F300 && r <= 0x1F64F) || // Misc Symbols and Pictographs, Emoticons
	   (r >= 0x1F680 && r <= 0x1F6FF) || // Transport and Map Symbols
	   (r >= 0x1F900 && r <= 0x1F9FF) || // Supplemental Symbols and Pictographs
	   (r >= 0x1FA70 && r <= 0x1FAFF) || // Symbols and Pictographs Extended-A
	   (r >= 0x20000 && r <= 0x2FFFF) { 	// CJK Extension B, C, D, E
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
	out_buffer :=
		strings.builder_make_len_cap(0, 4096, allocator) or_else strings.builder_make(allocator)
	last_frame :=
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
		out_buffer = out_buffer,
		last_frame = last_frame,
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
	out_buffer :=
		strings.builder_make_len_cap(0, 4096, allocator) or_else strings.builder_make(allocator)
	last_frame :=
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
		out_buffer = out_buffer,
		last_frame = last_frame,
		allocator = allocator,
	}
}

// Free the buffers owned by a program.
// run() does this on exit; call it yourself if you build a program without
// running it.
destroy_program :: proc(program: ^Program($Model, $Msg)) {
	strings.builder_destroy(&program.buffer)
	strings.builder_destroy(&program.out_buffer)
	strings.builder_destroy(&program.last_frame)
}

// ============================================================
// SCREEN MODE CONTROL
// ============================================================

// Toggle between fullscreen and inline mode
toggle_screen_mode :: proc(program: ^Program($Model, $Msg)) {
	if program.screen_mode == .Fullscreen {
		// Switching from fullscreen to inline
		term_write("\x1b[?1049l") // Disable alternative screen
		program.screen_mode = .Inline
		program.last_line_count = 0 // Reset line count for inline mode
		set_cleanup_altscreen(false)
	} else {
		// Switching from inline to fullscreen
		// First, clear the inline content by moving up and clearing
		if program.last_line_count > 0 {
			term_write("\r")
			term_write(fmt.tprintf("\x1b[%dA", program.last_line_count)) // Move up
			term_write("\x1b[J") // Clear from cursor down
		}
		term_write("\x1b[?1049h") // Enable alternative screen
		program.screen_mode = .Fullscreen
		program.last_line_count = 0 // Reset line count
		set_cleanup_altscreen(true)
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

// Run the program.
//
// Returns false if the terminal could not be put into raw mode - which is the
// normal outcome when stdin is not a terminal - and true after a normal exit.
// The program's buffers are released either way.
run :: proc(
	program: ^Program($Model, $Msg),
	input_handler: proc() -> Maybe(Msg),
	target_fps: i64 = 60,
	initial_mode: Screen_Mode = .Fullscreen,
	clear_on_exit: bool = true,
	enable_mouse: bool = false, // Mouse tracking is opt-in to avoid terminal weirdness
) -> (ok_run: bool) {
	// Set initial screen mode and clear on exit option
	program.screen_mode = initial_mode
	program.clear_on_exit = clear_on_exit

	// Set up terminal.
	// On failure the program's buffers must still be released: this returns
	// before the defers below are registered, and a failure here is the
	// ordinary path whenever stdin is not a terminal (a pipe, cron, CI).
	state, ok := set_raw_mode()
	if !ok {
		fmt.eprintln("Failed to set raw mode")
		destroy_program(program)
		return false
	}
	defer restore_mode(state)
	defer destroy_program(program)

	// Clear screen on exit if requested
	defer {
		if program.clear_on_exit {
			if program.screen_mode == .Inline && program.last_line_count > 0 {
				// In inline mode, clear the rendered content
				term_write("\r")
				term_write(fmt.tprintf("\x1b[%dA", program.last_line_count))
				term_write("\x1b[J")
			} else if program.screen_mode == .Fullscreen {
				// In fullscreen mode, clear the screen
				term_write("\x1b[H\x1b[J")
			}
		}
	}

	// Use the program's allocator for the remainder of execution
	context.allocator = program.allocator

	// Enable alternative screen buffer (only if fullscreen mode).
	// NOTE: the disable must NOT be deferred inside this `if` - Odin's defer
	// is scoped to the enclosing block, so an `if`-local defer fires at the
	// end of the `if`, turning the alt screen straight back off.
	// The check on exit reads the current mode, so a toggle_screen_mode() in
	// between still leaves the alt screen balanced.
	used_altscreen := program.screen_mode == .Fullscreen
	if used_altscreen {
		term_write("\x1b[?1049h")
	}
	defer if program.screen_mode == .Fullscreen {
		term_write("\x1b[?1049l")
	}

	// Hide cursor
	term_write("\x1b[?25l")
	defer term_write("\x1b[?25h")

	// Disable line wrapping to prevent visual artifacts
	term_write("\x1b[?7l")
	defer term_write("\x1b[?7h")

	// Enable mouse tracking only if explicitly requested
	// ?1000 = Enable mouse tracking (button press/release)
	// ?1002 = Enable button event tracking (drag)
	// ?1003 = Enable all motion tracking (including hover)
	// ?1006 = Enable SGR extended mouse mode
	if enable_mouse {
		term_write("\x1b[?1000h\x1b[?1002h\x1b[?1003h\x1b[?1006h")
	}
	defer if enable_mouse {
		term_write("\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l")
	}

	// Setup window resize detection and terminal restore on fatal signals
	set_cleanup_state(enable_mouse, used_altscreen)
	setup_resize_handler()

	// Track if we need to redraw
	needs_redraw := true

	// Frame timing. Guard the divisor: target_fps = 0 would divide by zero.
	fps := max(target_fps, 1)
	FRAME_TIME := time.Second / time.Duration(fps)
	// Poll input more often than we draw so a keystroke is not sitting in the
	// buffer for a whole frame before anyone looks at it. The floor keeps a
	// very high target_fps from turning this into a busy spin.
	POLL_TIME := max(min(FRAME_TIME / 8, 2 * time.Millisecond), 100 * time.Microsecond)
	// Cap on events handled per iteration, so a large paste cannot starve
	// rendering - but high enough that pasted text is not throttled to one
	// character per frame the way it used to be.
	MAX_EVENTS_PER_ITERATION :: 256
	last_frame_time := time.now()

	// Main loop
	for program.running {
		frame_start := time.now()

		// Check for window resize
		if check_window_resized() {
			needs_redraw = true
		}

		// Drain all pending input. Handling only one event per iteration
		// capped throughput at target_fps events/second, so pasting a line of
		// text took seconds and overflowed the input buffer.
		for _ in 0 ..< MAX_EVENTS_PER_ITERATION {
			msg, has_msg := input_handler().?
			if !has_msg {
				break
			}
			new_model, should_quit := program.update(msg, program.model)
			program.model = new_model
			needs_redraw = true // Mark for redraw on input
			if should_quit {
				program.running = false
				break
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

			// Nothing changed since the last frame: an event that does not
			// alter the view (mouse motion, a key the app ignores, a resize
			// back to the same size) costs no terminal traffic at all.
			// Without this every such event retransmits the whole view.
			unchanged := output == strings.to_string(program.last_frame)

			// Assemble the whole frame - control sequences included - and
			// write it with a single syscall, so the terminal never sees a
			// half-updated screen between writes.
			strings.builder_reset(&program.out_buffer)

			// Handle inline mode rendering differently
			if unchanged {
				// Skip: nothing to send.
			} else if program.screen_mode == .Inline {
				// Count lines in new output
				new_line_count := count_lines(output)

				// Move cursor up by previous line count (skip on first render)
				if program.last_line_count > 0 {
					// Move to beginning of line first, then move up
					strings.write_string(&program.out_buffer, "\r")
					fmt.sbprintf(&program.out_buffer, "\x1b[%dA", program.last_line_count)
				}

				// Clear from cursor down and print new output
				strings.write_string(&program.out_buffer, "\x1b[J")
				strings.write_string(&program.out_buffer, output)

				// Update line count
				program.last_line_count = new_line_count
			} else {
				// Fullscreen mode - just print
				strings.write_string(&program.out_buffer, output)
			}

			if !unchanged {
				term_write(strings.to_string(program.out_buffer))

				strings.builder_reset(&program.last_frame)
				strings.write_string(&program.last_frame, output)
			}

			// Reset redraw flag and update last frame time
			needs_redraw = false
			last_frame_time = frame_start
		}

		// Sleep to prevent CPU spinning. Wake up at the input poll interval
		// rather than the frame interval, but never later than the next frame.
		now := time.now()
		sleep_for := POLL_TIME
		if needs_redraw {
			until_frame := FRAME_TIME - time.diff(last_frame_time, now)
			if until_frame < sleep_for {
				sleep_for = until_frame
			}
		}
		if sleep_for > 0 {
			time.sleep(sleep_for)
		}

		// Reset temp allocator at end of iteration
		free_all(context.temp_allocator)
	}

	return true
}
