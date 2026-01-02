package main

import munin "../../munin"
import comp "../../munin/components"
import "core:fmt"
import "core:math/rand"
import "core:mem"
import "core:strings"
import "core:time"

// --- Model ---

Grid :: [4][4]int

GameState :: enum {
	Playing,
	Won,
	Lost,
}

Model :: struct {
	grid:     Grid,
	score:    int,
	state:    GameState,
	won_game: bool, // To track if we already hit 2048 but continued
}

init :: proc() -> Model {
	m := Model {
		state = .Playing,
	}
	spawn_tile(&m.grid)
	spawn_tile(&m.grid)
	return m
}

// --- Messages ---

MoveUp :: struct {}
MoveDown :: struct {}
MoveLeft :: struct {}
MoveRight :: struct {}
Restart :: struct {}
Quit :: struct {}

Msg :: union {
	MoveUp,
	MoveDown,
	MoveLeft,
	MoveRight,
	Restart,
	Quit,
}

// --- Logic ---

spawn_tile :: proc(grid: ^Grid) {
	empty_cells := make([dynamic][2]int, 0, 16)
	defer delete(empty_cells)

	for r in 0 ..< 4 {
		for c in 0 ..< 4 {
			if grid[r][c] == 0 {
				append(&empty_cells, [2]int{r, c})
			}
		}
	}

	if len(empty_cells) > 0 {
		idx := rand.int_max(len(empty_cells))
		pos := empty_cells[idx]
		// 90% chance of 2, 10% chance of 4
		val := 2
		if rand.float32() > 0.9 {
			val = 4
		}
		grid[pos[0]][pos[1]] = val
	}
}

// Rotates grid 90 degrees clockwise
rotate_grid :: proc(grid: ^Grid) {
	new_grid: Grid
	for r in 0 ..< 4 {
		for c in 0 ..< 4 {
			new_grid[c][3 - r] = grid[r][c]
		}
	}
	grid^ = new_grid
}

// Slides and merges a single row to the left
slide_and_merge_row :: proc(row: ^[4]int, score: ^int) -> bool {
	changed := false

	// 1. Slide non-zero values to the left
	new_row: [4]int
	idx := 0
	for i in 0 ..< 4 {
		if row[i] != 0 {
			new_row[idx] = row[i]
			idx += 1
		}
	}
	if row^ != new_row {
		changed = true
	}
	row^ = new_row

	// 2. Merge adjacent equal values
	for i in 0 ..< 3 {
		if row[i] != 0 && row[i] == row[i + 1] {
			row[i] *= 2
			score^ += row[i]
			row[i + 1] = 0
			changed = true

			// Slide remaining after merge to fill gap
			for j in i + 1 ..< 3 {
				row[j] = row[j + 1]
			}
			row[3] = 0
		}
	}

	return changed
}

move_left :: proc(model: ^Model) -> bool {
	changed := false
	for r in 0 ..< 4 {
		if slide_and_merge_row(&model.grid[r], &model.score) {
			changed = true
		}
	}
	return changed
}

move_grid :: proc(model: ^Model, dir: int) -> bool {
	// Directions: 0=Left, 1=Down, 2=Right, 3=Up
	changed := false

	if dir == 0 { 	// Left
		changed = move_left(model)
	} else if dir == 2 { 	// Right
		// Mirror rows, move left, mirror back
		for r in 0 ..< 4 {
			tmp: [4]int
			for c in 0 ..< 4 {tmp[c] = model.grid[r][3 - c]}
			model.grid[r] = tmp
		}
		if move_left(model) {changed = true}
		for r in 0 ..< 4 {
			tmp: [4]int
			for c in 0 ..< 4 {tmp[c] = model.grid[r][3 - c]}
			model.grid[r] = tmp
		}
	} else if dir == 3 { 	// Up
		// Transpose, move left (col becomes row), transpose back
		transpose_grid(&model.grid)
		if move_left(model) {changed = true}
		transpose_grid(&model.grid)
	} else if dir == 1 { 	// Down
		// Transpose, move Right (using reverse), transpose back
		transpose_grid(&model.grid)
		// Move Right logic inline: Reverse, Left, Reverse
		for r in 0 ..< 4 {
			tmp: [4]int
			for c in 0 ..< 4 {tmp[c] = model.grid[r][3 - c]}
			model.grid[r] = tmp
		}
		if move_left(model) {changed = true}
		for r in 0 ..< 4 {
			tmp: [4]int
			for c in 0 ..< 4 {tmp[c] = model.grid[r][3 - c]}
			model.grid[r] = tmp
		}
		transpose_grid(&model.grid)
	}

	return changed
}

transpose_grid :: proc(grid: ^Grid) {
	for r in 0 ..< 4 {
		for c in r + 1 ..< 4 {
			grid[r][c], grid[c][r] = grid[c][r], grid[r][c]
		}
	}
}

can_move :: proc(grid: Grid) -> bool {
	// Check for empty cells
	for r in 0 ..< 4 {
		for c in 0 ..< 4 {
			if grid[r][c] == 0 {return true}
		}
	}
	// Check horizontally adjacent
	for r in 0 ..< 4 {
		for c in 0 ..< 3 {
			if grid[r][c] == grid[r][c + 1] {return true}
		}
	}
	// Check vertically adjacent
	for c in 0 ..< 4 {
		for r in 0 ..< 3 {
			if grid[r][c] == grid[r + 1][c] {return true}
		}
	}
	return false
}

check_status :: proc(model: ^Model) {
	// Check win
	if !model.won_game {
		for r in 0 ..< 4 {
			for c in 0 ..< 4 {
				if model.grid[r][c] == 2048 {
					model.state = .Won
					model.won_game = true // Allow continuing if they want, but usually game stops or asks
					return
				}
			}
		}
	}

	// Check loss
	if !can_move(model.grid) {
		model.state = .Lost
	}
}


// --- Update ---

update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	if model.state == .Lost {
		switch m in msg {
		case Restart:
			new_model = init()
		case Quit:
			should_quit = true
		case MoveUp, MoveDown, MoveLeft, MoveRight:
		// Ignore keys when lost
		}
		return new_model, should_quit
	}

	// Allow restarting even if won/playing
	if _, ok := msg.(Restart); ok {
		return init(), false
	}
	if _, ok := msg.(Quit); ok {
		return model, true
	}

	changed := false
	switch m in msg {
	case MoveLeft:
		changed = move_grid(&new_model, 0)
	case MoveRight:
		changed = move_grid(&new_model, 2)
	case MoveUp:
		changed = move_grid(&new_model, 3)
	case MoveDown:
		changed = move_grid(&new_model, 1)
	case Restart, Quit:
	// Handled above
	}

	if changed {
		spawn_tile(&new_model.grid)
		check_status(&new_model)
	}

	return new_model, should_quit
}

// --- View ---
// Theme Colors

// Theme Colors

// Theme Globals (initialized in init_theme)
THEME_BG: munin.Color
THEME_EMPTY: munin.Color
THEME_TEXT_DARK: munin.Color
THEME_TEXT_LIGHT: munin.Color

// Helper to get color from string with fallback
c :: proc(s: string) -> munin.Color {
	col, ok := munin.color_from_string(s).?
	if !ok {return munin.Basic_Color.White}
	return col
}

init_theme :: proc() {
	THEME_BG = c("#bbada0")
	THEME_EMPTY = c("#cdc1b4")
	THEME_TEXT_DARK = c("#776e65")
	THEME_TEXT_LIGHT = c("#f9f6f2")
}

get_tile_style :: proc(val: int) -> (bg: munin.Color, fg: munin.Color) {
	switch val {
	case 2:
		return c("#eee4da"), THEME_TEXT_DARK
	case 4:
		return c("#ede0c8"), THEME_TEXT_DARK
	case 8:
		return c("#f2b179"), THEME_TEXT_LIGHT
	case 16:
		return c("#f59563"), THEME_TEXT_LIGHT
	case 32:
		return c("#f67c5f"), THEME_TEXT_LIGHT
	case 64:
		return c("#f65e3b"), THEME_TEXT_LIGHT
	case 128:
		return c("#edcf72"), THEME_TEXT_LIGHT
	case 256:
		return c("#edcc61"), THEME_TEXT_LIGHT
	case 512:
		return c("#edc850"), THEME_TEXT_LIGHT
	case 1024:
		return c("#edc53f"), THEME_TEXT_LIGHT
	case 2048:
		return c("#edc22e"), THEME_TEXT_LIGHT
	case:
		return c("#3c3a32"), THEME_TEXT_LIGHT // Super high numbers
	}
}

view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)

	w, h, ok := munin.get_window_size()
	if !ok {w, h = 80, 24}

	// Layout Constants
	tile_w := 10
	tile_h := 3

	board_w := 4 * tile_w
	board_h := 4 * tile_h

	// Outer container padding
	outer_pad_x := 2
	outer_pad_y := 1

	outer_w := board_w + (outer_pad_x * 2)
	outer_h := board_h + (outer_pad_y * 2)

	start_x := (w - outer_w) / 2
	start_y := (h - outer_h) / 2

	// Ensure positive
	if start_x < 0 {start_x = 0}
	if start_y < 0 {start_y = 0}

	// --- Header (Title & Score) ---
	// "2048" Title
	title_x := start_x
	title_y := start_y - 4
	if title_y >= 0 {
		munin.move_cursor(buf, {title_x, title_y})
		munin.set_bold(buf)
		munin.set_color(buf, THEME_TEXT_DARK)
		strings.write_string(buf, "2048")
		munin.reset_style(buf)

		munin.print_at(buf, {title_x, title_y + 1}, "Join result to get 2048!", THEME_TEXT_DARK)
	}

	// Score Box
	score_str := fmt.tprintf("%d", model.score)
	score_box_w := 10
	if len(score_str) > score_box_w - 2 {score_box_w = len(score_str) + 4}
	score_x := start_x + outer_w - score_box_w
	score_y := start_y - 4

	if score_y >= 0 {
		// Draw score box
		comp.draw_box_filled(buf, {score_x, score_y}, score_box_w, 3, THEME_BG, .Rounded, THEME_BG)

		// "SCORE" label
		// "SCORE" label
		label := "SCORE"
		label_x := score_x + (score_box_w - len(label)) / 2
		munin.print_at(buf, {label_x, score_y}, label, c("#eee4da"))

		// Score value
		val_x := score_x + (score_box_w - len(score_str)) / 2
		munin.move_cursor(buf, {val_x, score_y + 1})
		munin.set_bg_color(buf, THEME_BG)
		munin.set_bold(buf)
		munin.set_color(buf, munin.Basic_Color.White)
		strings.write_string(buf, score_str)
		munin.reset_style(buf)
	}

	// --- Game Board Background ---
	comp.draw_box_filled(buf, {start_x, start_y}, outer_w, outer_h, THEME_BG, .Rounded, THEME_BG)

	grid_start_x := start_x + outer_pad_x
	grid_start_y := start_y + outer_pad_y

	// --- Tiles ---
	for r in 0 ..< 4 {
		for c in 0 ..< 4 {
			val := model.grid[r][c]
			x := grid_start_x + c * tile_w
			y := grid_start_y + r * tile_h

			// Clip
			if x < 0 || y < 0 {continue}

			// Determine colors
			bg: munin.Color
			fg: munin.Color
			if val == 0 {
				bg = THEME_EMPTY
				fg = THEME_TEXT_DARK
			} else {
				bg, fg = get_tile_style(val)
			}

			// Use Rounded style for tiles to match theme
			border_style := comp.Box_Style.Rounded

			if val == 0 {
				// Empty Tile
				// Same border color as BG for seamless look
				comp.draw_box_filled(buf, {x, y}, tile_w, tile_h, bg, border_style, bg)
			} else {
				// Numbered Tile
				text := fmt.tprintf("%d", val)

				// Draw box
				comp.draw_box_filled(buf, {x, y}, tile_w, tile_h, bg, border_style, bg)

				// Center Text
				txt_len := len(text)
				txt_x := x + (tile_w - txt_len) / 2
				txt_y := y + (tile_h / 2)

				munin.move_cursor(buf, {txt_x, txt_y})
				munin.set_bg_color(buf, bg)
				munin.set_bold(buf)
				munin.set_color(buf, fg)
				strings.write_string(buf, text)
				munin.reset_style(buf)
			}
		}
	}

	// Game Over / Win Overlay
	status_msg := ""
	status_color: munin.Color = THEME_TEXT_DARK
	if model.state == .Lost {
		status_msg = "Game Over! (R)estart"
		status_color = c("#776e65")
	} else if model.state == .Won {
		status_msg = "You Won! (R)estart"
		status_color = c("#edc22e")
	} else {
		status_msg = "Use WASD/Arrows to move, Q to quit"
		status_color = c("#776e65")
	}

	msg_x := start_x + (outer_w - len(status_msg)) / 2
	msg_y := start_y + outer_h
	if msg_y < h {
		munin.print_at(buf, {msg_x, msg_y}, status_msg, status_color)
	}
}


// --- Input ---

input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_key().?; ok {
		#partial switch event.key {
		case .Up:
			return MoveUp{}
		case .Down:
			return MoveDown{}
		case .Left:
			return MoveLeft{}
		case .Right:
			return MoveRight{}
		case .Char:
			switch event.char {
			case 'w', 'W':
				return MoveUp{}
			case 's', 'S':
				return MoveDown{}
			case 'a', 'A':
				return MoveLeft{}
			case 'd', 'D':
				return MoveRight{}
			case 'r', 'R':
				return Restart{}
			case 'q', 'Q', 3:
				return Quit{}
			}
		}
	}
	return nil
}

// --- Main ---

main :: proc() {
	// Seed RNG
	rand.reset(u64(time.now()._nsec))

	// Init Theme
	init_theme()

	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	program := munin.make_program(init, update, view)
	munin.run(&program, input_handler)
}
