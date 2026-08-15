package components

import munin ".."

// ============================================================
// UNTRUSTED TEXT
// ============================================================

// Components that display *data* - table cells, list items, tree labels,
// input contents - strip escape sequences and control bytes from that text
// before drawing it, because it usually comes from somewhere the application
// did not author: a database, a log file, a filename, an API response. An
// unfiltered escape sequence in any of those lets the data drive the terminal
// instead of merely appearing in it (moving the cursor, rewriting the window
// title, or driving OSC 52 to write the user's clipboard).
//
// Column width is no defence: an escape sequence measures zero cells, so
// truncation never removes it.
//
// The low-level primitives (munin.print_at, munin.printf_at, the draw_text_*
// helpers) deliberately do *not* sanitize - they exist to emit output your own
// code composed, styling included. Sanitize before handing untrusted text to
// them: munin.sanitize_display(s).
//
// Every affected component takes `sanitize: bool = true`; pass false when the
// text is yours and is meant to carry styling.
@(private)
display_text :: proc(s: string, sanitize: bool) -> string {
	if !sanitize {
		return s
	}
	// Allocation-free when there is nothing to strip.
	return munin.sanitize_display(s)
}
