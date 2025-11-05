package munin

import "core:strings"
import "core:testing"

// ============================================================
// MOCK INFRASTRUCTURE FOR TESTING
// ============================================================

// Mock buffer for capturing terminal output
Mock_Terminal :: struct {
	output: strings.Builder,
	width:  int,
	height: int,
}

// Create a new mock terminal with given dimensions
make_mock_terminal :: proc(width, height: int, allocator := context.allocator) -> Mock_Terminal {
	buf := strings.builder_make_len_cap(0, 4096, allocator)
	return Mock_Terminal{
		output = buf,
		width = width,
		height = height,
	}
}

// Destroy mock terminal and free resources
destroy_mock_terminal :: proc(mock: ^Mock_Terminal) {
	strings.builder_destroy(&mock.output)
}

// Reset mock terminal output
reset_mock_terminal :: proc(mock: ^Mock_Terminal) {
	strings.builder_reset(&mock.output)
}

// Get the output from mock terminal
get_mock_output :: proc(mock: ^Mock_Terminal) -> string {
	return strings.to_string(mock.output)
}

// ============================================================
// TEST HELPERS
// ============================================================

// Check if a string contains a substring (for testing output)
assert_contains :: proc(t: ^testing.T, haystack, needle: string, msg := "", loc := #caller_location) {
	if !strings.contains(haystack, needle) {
		testing.errorf(t, "Expected string to contain '%s', got '%s'. %s", needle, haystack, msg, loc = loc)
	}
}

// Check if a string does not contain a substring
assert_not_contains :: proc(t: ^testing.T, haystack, needle: string, msg := "", loc := #caller_location) {
	if strings.contains(haystack, needle) {
		testing.errorf(t, "Expected string NOT to contain '%s', but it does. %s", needle, msg, loc = loc)
	}
}

// Check if two strings are equal
assert_string_equal :: proc(t: ^testing.T, expected, actual: string, msg := "", loc := #caller_location) {
	if expected != actual {
		testing.errorf(t, "Expected '%s', got '%s'. %s", expected, actual, msg, loc = loc)
	}
}

// Count occurrences of a substring in a string
count_occurrences :: proc(haystack, needle: string) -> int {
	if len(needle) == 0 {
		return 0
	}

	count := 0
	offset := 0
	for {
		idx := strings.index(haystack[offset:], needle)
		if idx == -1 {
			break
		}
		count += 1
		offset += idx + len(needle)
	}
	return count
}

// Parse ANSI escape sequence at position
// Returns the sequence length or 0 if not an escape sequence
parse_ansi_at :: proc(s: string, pos: int) -> int {
	if pos >= len(s) || s[pos] != 0x1b {
		return 0
	}

	i := pos + 1
	if i >= len(s) {
		return 0
	}

	// CSI sequences (ESC [ ...)
	if s[i] == '[' {
		i += 1
		for i < len(s) {
			ch := s[i]
			i += 1
			if (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') {
				return i - pos
			}
		}
	}

	// OSC sequences (ESC ] ...)
	if s[i] == ']' {
		i += 1
		for i < len(s) {
			if s[i] == 0x07 {
				return i + 1 - pos
			}
			if s[i] == 0x1b && i+1 < len(s) && s[i+1] == '\\' {
				return i + 2 - pos
			}
			i += 1
		}
	}

	return 0
}

// Extract visible text from string (strip ANSI codes)
extract_visible_text :: proc(s: string, allocator := context.temp_allocator) -> string {
	return strip_ansi(s)
}
