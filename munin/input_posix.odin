package munin

import "core:os"
import "core:time"
import "core:unicode/utf8"

when ODIN_OS != .Windows {

	// Bytes read from the terminal that have not yet been parsed into events.
	//
	// Terminal input arrives in arbitrary chunks: an escape sequence can be
	// split across two reads, and a paste delivers hundreds of bytes at once.
	// Keeping the partial state in a named type (rather than three loose
	// globals) makes the whole pipeline testable without a terminal, and
	// leaves room for input to become per-program later.
	Input_Buffer :: struct {
		data:      [1024]byte,
		len:       int,
		last_read: time.Time,
	}

	// The buffer read_input()/read_key() use. Input handling is
	// single-threaded: these must only be called from the thread running the
	// program loop.
	@(private)
	stdin_input: Input_Buffer

	// Longest escape sequence we are willing to buffer before deciding the
	// stream is garbage and resynchronising.
	@(private)
	MAX_ESCAPE_SEQ_LEN :: 64

	// Upper bound for a numeric field in an escape sequence. Terminals never
	// legitimately exceed this, and it keeps parsed coordinates in a range
	// that cannot blow up an application's array indexing.
	@(private)
	MAX_SEQ_NUMBER :: 9999

	// Helper: Parse a single event from a buffer
	// Returns: event, consumed_bytes, success
	utf8_sequence_size :: proc(first: byte) -> int {
		if first < 0x80 {
			return 1
		}
		if first >= 0xC2 && first <= 0xDF {
			return 2
		}
		if first >= 0xE0 && first <= 0xEF {
			return 3
		}
		if first >= 0xF0 && first <= 0xF4 {
			return 4
		}
		return 0
	}

	is_utf8_continuation :: proc(b: byte) -> bool {
		return (b & 0xC0) == 0x80
	}

	// Parse a decimal field, rejecting anything that is not a run of digits.
	// Without this an attacker-controlled (or simply corrupt) sequence turns
	// into arbitrary integers via `b - '0'` on non-digit bytes.
	@(private)
	parse_seq_number :: proc(s: []byte) -> (int, bool) {
		if len(s) == 0 || len(s) > 5 {
			return 0, false
		}
		v := 0
		for b in s {
			if b < '0' || b > '9' {
				return 0, false
			}
			v = v * 10 + int(b - '0')
			if v > MAX_SEQ_NUMBER {
				return 0, false
			}
		}
		return v, true
	}

	// Decode the xterm modifier parameter (1 + bitmask) used by sequences
	// like ESC [ 1 ; 5 A (Ctrl+Up).
	@(private)
	apply_modifier :: proc(ev: ^Key_Event, modifier: int) {
		if modifier <= 1 {
			return
		}
		bits := modifier - 1
		ev.shift = (bits & 1) != 0
		ev.alt = (bits & 2) != 0
		ev.ctrl = (bits & 4) != 0
	}

	// Split a CSI parameter string into its first numeric parameter and its
	// trailing modifier parameter, e.g. "1;5" -> (1, 5).
	@(private)
	split_csi_params :: proc(params: []byte) -> (first: int, modifier: int, ok: bool) {
		if len(params) == 0 {
			return 0, 1, true
		}

		semi := -1
		for i in 0 ..< len(params) {
			if params[i] == ';' {
				semi = i
				break
			}
		}

		if semi == -1 {
			first = parse_seq_number(params) or_return
			return first, 1, true
		}

		first = parse_seq_number(params[:semi]) or_return
		modifier = parse_seq_number(params[semi + 1:]) or_return
		return first, modifier, true
	}

	// Parse a plain character or control byte (no escape prefix).
	@(private)
	parse_char_event :: proc(buf: []byte) -> (Key_Event, int, bool) {
		if len(buf) == 0 {
			return {}, 0, false
		}

		switch buf[0] {
		case 13, 10:
			return Key_Event{key = .Enter}, 1, true
		case 127, 8:
			return Key_Event{key = .Backspace}, 1, true
		case 9:
			return Key_Event{key = .Tab}, 1, true
		}

		// Ctrl+A .. Ctrl+Z (minus the ones handled above).
		if buf[0] >= 1 && buf[0] <= 26 {
			return Key_Event{key = .Char, char = rune('a' + buf[0] - 1), ctrl = true}, 1, true
		}

		// Remaining C0 controls have no useful mapping.
		if buf[0] < 0x20 {
			return Key_Event{key = .Unknown}, 1, true
		}

		size := utf8_sequence_size(buf[0])
		if size == 0 {
			return Key_Event{key = .Char, char = utf8.RUNE_ERROR}, 1, true
		}
		if len(buf) < size {
			return {}, 0, false
		}
		for i in 1 ..< size {
			if !is_utf8_continuation(buf[i]) {
				return Key_Event{key = .Char, char = utf8.RUNE_ERROR}, 1, true
			}
		}

		r, decoded_size := utf8.decode_rune(buf[:size])
		if r == utf8.RUNE_ERROR || decoded_size != size {
			return Key_Event{key = .Char, char = utf8.RUNE_ERROR}, 1, true
		}
		return Key_Event{key = .Char, char = r}, size, true
	}

	// Parse a CSI sequence (ESC [ ... final).
	// Per ECMA-48 a CSI is: parameter bytes 0x30-0x3F, intermediate bytes
	// 0x20-0x2F, then a single final byte 0x40-0x7E. Consuming the whole
	// sequence matters: bailing out after the ESC leaves the remainder of the
	// sequence in the stream, where it is delivered to the application as
	// literal keystrokes.
	@(private)
	parse_csi :: proc(buf: []byte) -> (Input_Event, int, bool) {
		i := 2
		for i < len(buf) {
			b := buf[i]
			if b >= 0x40 && b <= 0x7E {
				break
			}
			if b < 0x20 || b > 0x3F {
				// Not a valid CSI body byte: drop "ESC [" and resynchronise.
				return Key_Event{key = .Unknown}, 2, true
			}
			i += 1
		}

		if i >= len(buf) {
			// Incomplete, unless it has grown implausibly long.
			if len(buf) >= MAX_ESCAPE_SEQ_LEN {
				return Key_Event{key = .Unknown}, 2, true
			}
			return nil, 0, false
		}

		final := buf[i]
		params := buf[2:i]
		total := i + 1

		// SGR mouse: ESC [ < Cb ; Cx ; Cy M/m
		if len(params) > 0 && params[0] == '<' && (final == 'M' || final == 'm') {
			if mouse, ok := parse_sgr_mouse(buf[:total], total).?; ok {
				return mouse, total, true
			}
			return Key_Event{key = .Unknown}, total, true
		}

		first, modifier, ok := split_csi_params(params)
		if !ok {
			return Key_Event{key = .Unknown}, total, true
		}

		ev: Key_Event
		switch final {
		case 'A':
			ev = Key_Event{key = .Up}
		case 'B':
			ev = Key_Event{key = .Down}
		case 'C':
			ev = Key_Event{key = .Right}
		case 'D':
			ev = Key_Event{key = .Left}
		case 'Z':
			return Key_Event{key = .Tab, shift = true}, total, true
		case '~':
			switch first {
			case 5:
				ev = Key_Event{key = .PageUp}
			case 6:
				ev = Key_Event{key = .PageDown}
			case:
				return Key_Event{key = .Unknown}, total, true
			}
		case:
			return Key_Event{key = .Unknown}, total, true
		}

		apply_modifier(&ev, modifier)
		return ev, total, true
	}

	// Parse an SS3 sequence (ESC O final) - arrows in application cursor mode.
	@(private)
	parse_ss3 :: proc(buf: []byte) -> (Input_Event, int, bool) {
		if len(buf) < 3 {
			return nil, 0, false
		}
		switch buf[2] {
		case 'A':
			return Key_Event{key = .Up}, 3, true
		case 'B':
			return Key_Event{key = .Down}, 3, true
		case 'C':
			return Key_Event{key = .Right}, 3, true
		case 'D':
			return Key_Event{key = .Left}, 3, true
		}
		return Key_Event{key = .Unknown}, 3, true
	}

	parse_event_from_buffer :: proc(buf: []byte) -> (Input_Event, int, bool) {
		if len(buf) == 0 {
			return nil, 0, false
		}

		// Handle Escape Sequences
		if buf[0] == 0x1b {
			// Just ESC? We cannot tell a bare Escape key from the start of a
			// sequence without waiting; read_input resolves it on timeout.
			if len(buf) == 1 {
				return nil, 0, false
			}

			switch buf[1] {
			case '[':
				return parse_csi(buf)
			case 'O':
				return parse_ss3(buf)
			}

			// ESC followed by a key is Alt+key.
			ev, consumed, ok := parse_char_event(buf[1:])
			if !ok {
				if len(buf) >= MAX_ESCAPE_SEQ_LEN {
					return Key_Event{key = .Escape}, 1, true
				}
				return nil, 0, false
			}
			ev.alt = true
			return ev, consumed + 1, true
		}

		return parse_char_event(buf)
	}

	// Parse SGR mouse event (format: ESC [ < Cb ; Cx ; Cy M/m)
	// This is the preferred format with better coordinate support.
	// Every numeric field is validated; a malformed sequence is rejected
	// rather than turned into a garbage coordinate.
	parse_sgr_mouse :: proc(buf: []byte, n: int) -> Maybe(Mouse_Event) {
		if n < 9 || n > len(buf) || buf[0] != 27 || buf[1] != '[' || buf[2] != '<' {
			return nil
		}

		// Find semicolons and M/m terminator
		semi1, semi2, end := -1, -1, -1
		for i in 3 ..< n {
			if buf[i] == ';' {
				if semi1 == -1 {
					semi1 = i
				} else if semi2 == -1 {
					semi2 = i
				}
			} else if buf[i] == 'M' || buf[i] == 'm' {
				end = i
				break
			}
		}

		if semi1 == -1 || semi2 == -1 || end == -1 {
			return nil
		}
		if !(semi1 < semi2 && semi2 < end) {
			return nil
		}

		cb, cb_ok := parse_seq_number(buf[3:semi1])
		if !cb_ok {
			return nil
		}
		cx, cx_ok := parse_seq_number(buf[semi1 + 1:semi2])
		if !cx_ok {
			return nil
		}
		cy, cy_ok := parse_seq_number(buf[semi2 + 1:end])
		if !cy_ok {
			return nil
		}

		// Determine event type (M = press, m = release)
		event_type := Mouse_Event_Type.Press if buf[end] == 'M' else .Release

		// Extract modifiers from high bits
		shift := (cb & 0x04) != 0
		alt := (cb & 0x08) != 0
		ctrl := (cb & 0x10) != 0
		motion := (cb & 0x20) != 0 // Bit 5 indicates motion/drag

		button: Mouse_Button

		// Check for wheel events first (codes 64-65 base, with modifiers in high bits)
		// Wheel events have bit pattern: 64 (0x40) for up, 65 (0x41) for down
		base_code := cb & 0x43 // Mask to get base wheel code
		if base_code == 64 || base_code == 65 {
			button = .WheelUp if base_code == 64 else .WheelDown
			event_type = .Press
		} else {
			// Regular button events - extract from low 2 bits
			button_code := cb & 0x03
			switch button_code {
			case 0:
				button = .Left
			case 1:
				button = .Middle
			case 2:
				button = .Right
			case 3:
				// Button 3 with motion bit typically means hover (no button pressed)
				button = .None
			}
		}

		// Determine if this is drag or hover based on motion bit and button state
		if motion && event_type == .Press {
			if button == .None {
				// Motion with no button = hover
				event_type = .Move
			} else {
				// Motion with button = drag
				event_type = .Drag
			}
		}

		// Coordinates are 1-based in the protocol. A zero field would map to
		// -1, so clamp at the origin.
		return Mouse_Event {
			button = button,
			type   = event_type,
			x      = max(cx - 1, 0),
			y      = max(cy - 1, 0),
			shift  = shift,
			ctrl   = ctrl,
			alt    = alt,
		}
	}

	// Append bytes to the buffer, dropping whatever does not fit.
	// Returns the number of bytes accepted.
	input_buffer_feed :: proc(b: ^Input_Buffer, bytes: []byte, now: Maybe(time.Time) = nil) -> int {
		space := len(b.data) - b.len
		if space <= 0 || len(bytes) == 0 {
			return 0
		}

		n := min(space, len(bytes))
		copy(b.data[b.len:], bytes[:n])
		b.len += n
		b.last_read = now.? or_else time.now()
		return n
	}

	// Parse the next event out of the buffer.
	//
	// Returns nil while the buffer holds only an incomplete sequence, unless
	// waiting can no longer help: the buffer is full (nothing more can be
	// read) or the sequence has been sitting there long enough that a bare
	// Escape is the better explanation.
	input_buffer_next :: proc(b: ^Input_Buffer, now: Maybe(time.Time) = nil) -> Maybe(Input_Event) {
		if b.len == 0 {
			return nil
		}

		event, consumed, ok := parse_event_from_buffer(b.data[:b.len])

		if ok && consumed > 0 {
			copy(b.data[:], b.data[consumed:b.len])
			b.len -= consumed
			return event
		}

		buffer_full := b.len >= len(b.data)
		timed_out := time.diff(b.last_read, now.? or_else time.now()) > ESCAPE_TIMEOUT

		if buffer_full || timed_out {
			first := b.data[0]
			copy(b.data[:], b.data[1:b.len])
			b.len -= 1

			if first == 0x1b {
				return Key_Event{key = .Escape}
			}
			ev, _, parsed := parse_char_event([]byte{first})
			if parsed {
				return ev
			}
			return nil
		}

		// Keep the data in the buffer for next time
		return nil
	}

	// How long an incomplete escape sequence is given before it is treated as
	// a bare Escape key.
	ESCAPE_TIMEOUT :: 50 * time.Millisecond

	read_input :: proc() -> Maybe(Input_Event) {
		// Unix/Linux/macOS
		if stdin_input.len < len(stdin_input.data) {
			// Non-blocking because VMIN=0/VTIME=0
			scratch := stdin_input.data[stdin_input.len:]
			n, err := os.read(os.stdin, scratch)
			if err == nil && n > 0 {
				stdin_input.len += n
				stdin_input.last_read = time.now()
			}
		}

		return input_buffer_next(&stdin_input)
	}
}
