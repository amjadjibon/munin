package munin

// ============================================================
// INPUT TYPES
// ============================================================

Key :: enum {
	Unknown,
	Char,
	Up,
	Down,
	Left,
	Right,
	Enter,
	Escape,
	Backspace,
	Tab,
	PageUp,
	PageDown,
}

Key_Event :: struct {
	key:   Key,
	char:  rune,
	shift: bool,
	ctrl:  bool,
	alt:   bool,
}

// Mouse button types
Mouse_Button :: enum {
	None,
	Left,
	Right,
	Middle,
	WheelUp,
	WheelDown,
}

// Mouse event types
Mouse_Event_Type :: enum {
	Press,
	Release,
	Drag,
	Move,
}

// Mouse event structure
Mouse_Event :: struct {
	button: Mouse_Button,
	type:   Mouse_Event_Type,
	x:      int,
	y:      int,
	shift:  bool,
	ctrl:   bool,
	alt:    bool,
}

// Input event can be either keyboard or mouse
Input_Event :: union {
	Key_Event,
	Mouse_Event,
}

// ============================================================
// PUBLIC API
// ============================================================

read_key :: proc() -> Maybe(Key_Event) {
	// Reuse read_input and filter
	if event, ok := read_input().?; ok {
		#partial switch e in event {
		case Key_Event:
			return e
		}
	}
	return nil
}
