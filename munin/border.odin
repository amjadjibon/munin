package munin

// Border definition containing characters for all parts of a border
Border :: struct {
	top:          string,
	bottom:       string,
	left:         string,
	right:        string,
	top_left:     string,
	top_right:    string,
	bottom_left:  string,
	bottom_right: string,
}

// Predefined border styles
Border_Normal :: Border{"─", "─", "│", "│", "┌", "┐", "└", "┘"}
Border_Rounded :: Border{"─", "─", "│", "│", "╭", "╮", "╰", "╯"}
Border_Thick :: Border{"━", "━", "┃", "┃", "┏", "┓", "┗", "┛"}
Border_Double :: Border{"═", "═", "║", "║", "╔", "╗", "╚", "╝"}
Border_Hidden :: Border{" ", " ", " ", " ", " ", " ", " ", " "}

// Helper to check if a border is set (not empty)
has_border :: proc(b: Border) -> bool {
	return b.top != "" || b.bottom != "" || b.left != "" || b.right != ""
}
