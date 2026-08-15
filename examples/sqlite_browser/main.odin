package main

import comp "../../munin/components"
import munin "../../munin"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"

when ODIN_OS != .Windows {
	foreign import sqlite "system:sqlite3"

	sqlite3 :: struct {}
	sqlite3_stmt :: struct {}

	SQLITE_OK :: 0
	SQLITE_ROW :: 100
	SQLITE_DONE :: 101

	// Tells SQLite to copy the bound text; the Odin-side string may be in the
	// temp arena and gone by the time the statement runs.
	SQLITE_TRANSIENT := rawptr(~uintptr(0))

	@(default_calling_convention = "c")
	foreign sqlite {
		sqlite3_open :: proc(filename: cstring, ppDb: ^^sqlite3) -> c.int ---
		sqlite3_close :: proc(db: ^sqlite3) -> c.int ---
		sqlite3_exec :: proc(
			db: ^sqlite3,
			sql: cstring,
			callback: rawptr,
			data: rawptr,
			errmsg: ^cstring,
		) -> c.int ---
		sqlite3_free :: proc(ptr: rawptr) ---
		sqlite3_errmsg :: proc(db: ^sqlite3) -> cstring ---
		sqlite3_prepare_v2 :: proc(
			db: ^sqlite3,
			sql: cstring,
			nByte: c.int,
			ppStmt: ^^sqlite3_stmt,
			pzTail: ^cstring,
		) -> c.int ---
		sqlite3_bind_text :: proc(
			stmt: ^sqlite3_stmt,
			index: c.int,
			text: cstring,
			nByte: c.int,
			destructor: rawptr,
		) -> c.int ---
		sqlite3_step :: proc(stmt: ^sqlite3_stmt) -> c.int ---
		sqlite3_finalize :: proc(stmt: ^sqlite3_stmt) -> c.int ---
		sqlite3_column_count :: proc(stmt: ^sqlite3_stmt) -> c.int ---
		sqlite3_column_name :: proc(stmt: ^sqlite3_stmt, iCol: c.int) -> cstring ---
		sqlite3_column_text :: proc(stmt: ^sqlite3_stmt, iCol: c.int) -> cstring ---
	}
}

Focus :: enum {
	Tables,
	Query,
	Results,
}

Query_Result :: struct {
	columns: [dynamic]string,
	rows:    [dynamic][dynamic]string,
	error:   string,
}

Model :: struct {
	db:             ^sqlite3,
	db_path:        string,
	is_memory_db:   bool,
	tables:         [dynamic]string,
	selected_table: int,
	focus:          Focus,
	query:          ^comp.Input_State,
	result:         Query_Result,
	schema:         string,
	page:           int,
	page_size:      int,
	status:         string,
}

Quit :: struct {}
	NextTable :: struct {}
PrevTable :: struct {}
NextFocus :: struct {}
RunQuery :: struct {}
LoadTable :: struct {}
NextPage :: struct {}
PrevPage :: struct {}
AddChar :: struct {
	char: rune,
}
Backspace :: struct {}
MoveLeft :: struct {}
MoveRight :: struct {}

Msg :: union {
	Quit,
	NextTable,
	PrevTable,
	NextFocus,
	RunQuery,
	LoadTable,
	NextPage,
	PrevPage,
	AddChar,
	Backspace,
	MoveLeft,
	MoveRight,
}

initial_model: Model

main :: proc() {
	when ODIN_OS == .Windows {
		fmt.eprintln("sqlite_browser uses libsqlite3 through C FFI and is currently implemented for POSIX platforms.")
		return
	}

	initial_model = init()
	if initial_model.db == nil {
		fmt.eprintln(initial_model.status)
		return
	}

	program := munin.make_program(program_init, update, view)
	munin.run(&program, input_handler, target_fps = 30)
	cleanup_model(&program.model)
}

program_init :: proc() -> Model {
	return initial_model
}

init :: proc() -> Model {
	args := os.args
	db_path := ":memory:"
	is_memory_db := true
	if len(args) > 1 {
		db_path = args[1]
		is_memory_db = false
	}

	query := new(comp.Input_State)
	query^ = comp.make_input_state(512, "select * from table_name limit 50")

	model := Model {
		db_path = strings.clone(db_path),
		is_memory_db = is_memory_db,
		tables = make([dynamic]string),
		selected_table = 0,
		focus = .Tables,
		query = query,
		page = 0,
		page_size = 8,
		status = "",
	}

	if !open_database(&model) {
		return model
	}
	if model.is_memory_db {
		if err := exec_sql(model.db, SAMPLE_SQL); len(err) > 0 {
			set_status(&model, err)
			return model
		}
		set_status(&model, "Opened sample in-memory database")
	} else {
		set_status(&model, fmt.tprintf("Opened %s", model.db_path))
	}

	refresh_tables(&model)
	if len(model.tables) > 0 {
		load_selected_table(&model)
	}
	return model
}

SAMPLE_SQL :: `
create table projects (
	id integer primary key,
	name text not null,
	status text not null,
	owner text not null,
	updated_at text not null
);
insert into projects (name, status, owner, updated_at) values
	('Munin', 'active', 'Amjad', '2026-05-29'),
	('Relay Service', 'review', 'Nora', '2026-05-27'),
	('Data Importer', 'paused', 'Kai', '2026-05-24'),
	('Metrics UI', 'active', 'Sana', '2026-05-21');

create table tasks (
	id integer primary key,
	project_id integer not null,
	title text not null,
	priority text not null,
	done integer not null default 0,
	foreign key(project_id) references projects(id)
);
insert into tasks (project_id, title, priority, done) values
	(1, 'Fix UTF-8 cursor movement', 'high', 1),
	(1, 'Add SQLite browser demo', 'high', 0),
	(1, 'Smoke test examples', 'medium', 0),
	(2, 'Document auth flow', 'medium', 1),
	(3, 'Retry failed imports', 'low', 0),
	(4, 'Tune table layout', 'medium', 0);

create view active_tasks as
select p.name as project, t.title, t.priority
from tasks t
join projects p on p.id = t.project_id
where t.done = 0;
`

open_database :: proc(model: ^Model) -> bool {
	path_c, path_err := strings.clone_to_cstring(model.db_path, context.temp_allocator)
	if path_err != nil {
		set_status(model, "Failed to allocate database path")
		return false
	}
	if sqlite3_open(path_c, &model.db) != SQLITE_OK {
		set_status(model, db_error(model.db))
		return false
	}
	return true
}

exec_sql :: proc(db: ^sqlite3, sql: string) -> string {
	sql_c, sql_err := strings.clone_to_cstring(sql, context.temp_allocator)
	if sql_err != nil {
		return "Failed to allocate SQL text"
	}
	err_msg: cstring
	rc := sqlite3_exec(db, sql_c, nil, nil, &err_msg)
	if rc != SQLITE_OK {
		defer if err_msg != nil {sqlite3_free(rawptr(err_msg))}
		if err_msg != nil {
			return strings.clone(string(err_msg))
		}
		return db_error(db)
	}
	return ""
}

db_error :: proc(db: ^sqlite3) -> string {
	if db == nil {
		return "SQLite failed before database handle was available"
	}
	return strings.clone(string(sqlite3_errmsg(db)))
}

set_status :: proc(model: ^Model, status: string) {
	if len(model.status) > 0 {
		delete(model.status)
	}
	model.status = strings.clone(status)
}

refresh_tables :: proc(model: ^Model) {
	clear_strings(&model.tables)

	result := run_select(
		model.db,
		"select name from sqlite_schema where type in ('table', 'view') and name not like 'sqlite_%' order by type, name",
		200,
	)
	defer clear_result(&result)

	if len(result.error) > 0 {
		set_status(model, result.error)
		return
	}

	for row in result.rows {
		if len(row) > 0 {
			append(&model.tables, strings.clone(row[0]))
		}
	}
	model.selected_table = clamp(model.selected_table, 0, max(0, len(model.tables) - 1))
}

load_selected_table :: proc(model: ^Model) {
	if len(model.tables) == 0 {
		return
	}

	table := model.tables[model.selected_table]
	query := fmt.tprintf("select * from %s limit 200", quote_identifier(table))
	set_query_text(model.query, query)
	model.result = run_select(model.db, query, 200)
	model.page = 0
	load_schema(model, table)
	set_status(model, fmt.tprintf("Loaded %s (%d rows)", table, len(model.result.rows)))
}

// SQLite identifiers cannot be bound as parameters, so they have to be quoted:
// wrap in double quotes and double any double quote inside. Without this a
// table named `x" ...` ends the identifier early and the rest of the name is
// executed as SQL.
quote_identifier :: proc(name: string, allocator := context.temp_allocator) -> string {
	b := strings.builder_make(allocator)
	strings.write_byte(&b, '"')
	for i in 0 ..< len(name) {
		if name[i] == '"' {
			strings.write_string(&b, "\"\"")
		} else {
			strings.write_byte(&b, name[i])
		}
	}
	strings.write_byte(&b, '"')
	return strings.to_string(b)
}

load_schema :: proc(model: ^Model, table: string) {
	if len(model.schema) > 0 {
		delete(model.schema)
		model.schema = ""
	}

	result := run_select(
		model.db,
		"select sql from sqlite_schema where name = ? limit 1",
		1,
		{table},
	)
	defer clear_result(&result)

	if len(result.rows) > 0 && len(result.rows[0]) > 0 {
		model.schema = strings.clone(result.rows[0][0])
	} else {
		model.schema = strings.clone("No schema found")
	}
}

run_current_query :: proc(model: ^Model) {
	query := comp.input_get_text(model.query)
	if len(strings.trim_space(query)) == 0 {
		set_status(model, "Query is empty")
		return
	}

	clear_result(&model.result)
	model.result = run_select(model.db, query, 500)
	model.page = 0

	if len(model.result.error) > 0 {
		set_status(model, model.result.error)
		return
	}

	if len(model.result.columns) == 0 {
		err := exec_sql(model.db, query)
		if len(err) > 0 {
			set_status(model, err)
			return
		}
		refresh_tables(model)
		set_status(model, "Statement executed")
		return
	}

	set_status(model, fmt.tprintf("Query returned %d rows", len(model.result.rows)))
}

// Values must be passed as bound parameters, never interpolated into the SQL
// text: a table name is data too, and SQLite happily accepts identifiers
// containing quotes.
run_select :: proc(
	db: ^sqlite3,
	sql: string,
	max_rows: int,
	params: []string = nil,
) -> Query_Result {
	result := Query_Result {
		columns = make([dynamic]string),
		rows = make([dynamic][dynamic]string),
	}

	sql_c, sql_err := strings.clone_to_cstring(sql, context.temp_allocator)
	if sql_err != nil {
		result.error = strings.clone("Failed to allocate SQL text")
		return result
	}
	stmt: ^sqlite3_stmt
	rc := sqlite3_prepare_v2(db, sql_c, -1, &stmt, nil)
	if rc != SQLITE_OK {
		result.error = db_error(db)
		return result
	}
	defer sqlite3_finalize(stmt)

	for value, i in params {
		value_c, value_err := strings.clone_to_cstring(value, context.temp_allocator)
		if value_err != nil {
			result.error = strings.clone("Failed to allocate parameter text")
			return result
		}
		if sqlite3_bind_text(stmt, c.int(i + 1), value_c, -1, SQLITE_TRANSIENT) != SQLITE_OK {
			result.error = db_error(db)
			return result
		}
	}

	col_count := int(sqlite3_column_count(stmt))
	for i in 0 ..< col_count {
		name := sqlite3_column_name(stmt, c.int(i))
		if name == nil {
			append(&result.columns, fmt.tprintf("col_%d", i + 1))
		} else {
			append(&result.columns, strings.clone(string(name)))
		}
	}

	row_count := 0
	for row_count < max_rows {
		step := sqlite3_step(stmt)
		if step == SQLITE_DONE {
			break
		}
		if step != SQLITE_ROW {
			result.error = db_error(db)
			break
		}

		row := make([dynamic]string)
		for i in 0 ..< col_count {
			text := sqlite3_column_text(stmt, c.int(i))
			if text == nil {
				append(&row, strings.clone("NULL"))
			} else {
				append(&row, strings.clone(string(text)))
			}
		}
		append(&result.rows, row)
		row_count += 1
	}

	return result
}

update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case Quit:
		should_quit = true
	case NextTable:
		if len(new_model.tables) > 0 {
			new_model.selected_table = min(new_model.selected_table + 1, len(new_model.tables) - 1)
			load_selected_table(&new_model)
		}
	case PrevTable:
		if len(new_model.tables) > 0 {
			new_model.selected_table = max(new_model.selected_table - 1, 0)
			load_selected_table(&new_model)
		}
	case NextFocus:
		new_model.focus = Focus((int(new_model.focus) + 1) % 3)
	case RunQuery:
		run_current_query(&new_model)
	case LoadTable:
		load_selected_table(&new_model)
	case NextPage:
		max_page := max(0, (len(new_model.result.rows) - 1) / new_model.page_size)
		new_model.page = min(new_model.page + 1, max_page)
	case PrevPage:
		new_model.page = max(new_model.page - 1, 0)
	case AddChar:
		if new_model.focus == .Query {
			comp.input_add_char(new_model.query, m.char)
		}
	case Backspace:
		if new_model.focus == .Query {
			comp.input_backspace(new_model.query)
		}
	case MoveLeft:
		if new_model.focus == .Query {
			comp.input_cursor_left(new_model.query)
		} else {
			new_model.page = max(new_model.page - 1, 0)
		}
	case MoveRight:
		if new_model.focus == .Query {
			comp.input_cursor_right(new_model.query)
		} else {
			max_page := max(0, (len(new_model.result.rows) - 1) / new_model.page_size)
			new_model.page = min(new_model.page + 1, max_page)
		}
	}

	return new_model, should_quit
}

view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)
	munin.set_window_title(buf, "Munin SQLite Browser")

	width, height, ok := munin.get_window_size()
	if !ok {
		width = 100
		height = 32
	}

	title := model.is_memory_db ? "SQLite Browser - Sample Database" : fmt.tprintf("SQLite Browser - %s", model.db_path)
	munin.draw_title(buf, {0, 0}, width, title, .BrightCyan, true)

	draw_tables(buf, model, {1, 2}, 24, height - 7)
	draw_schema(buf, model, {27, 2}, width - 28, 7)
	draw_query(buf, model, {27, 10}, width - 28)
	draw_results(buf, model, {27, 14}, width - 28, height - 18)
	draw_status(buf, model, {1, height - 3}, width)
}

draw_tables :: proc(buf: ^strings.Builder, model: Model, pos: munin.Vec2i, width, height: int) {
	color := model.focus == .Tables ? munin.Basic_Color.BrightYellow : munin.Basic_Color.BrightBlue
	comp.draw_box_titled(buf, pos, width, height, " Tables ", .Rounded, color, .BrightWhite)

	for table, i in model.tables {
		if i >= height - 2 {
			break
		}
		row_y := pos.y + 1 + i
		marker := i == model.selected_table ? ">" : " "
		text_color := i == model.selected_table ? munin.Basic_Color.BrightYellow : munin.Basic_Color.White
		munin.print_at(buf, {pos.x + 2, row_y}, marker, text_color)
		munin.print_at(buf, {pos.x + 4, row_y}, truncate(table, width - 6), text_color)
	}
}

draw_schema :: proc(buf: ^strings.Builder, model: Model, pos: munin.Vec2i, width, height: int) {
	comp.draw_box_titled(buf, pos, width, height, " Schema ", .Rounded, .BrightBlue, .BrightWhite)
	lines := strings.split(model.schema, "\n")
	defer delete(lines)
	for line, i in lines {
		if i >= height - 2 {
			break
		}
		munin.print_at(buf, {pos.x + 2, pos.y + 1 + i}, truncate(line, width - 4), .White)
	}
}

draw_query :: proc(buf: ^strings.Builder, model: Model, pos: munin.Vec2i, width: int) {
	color := model.focus == .Query ? munin.Basic_Color.BrightYellow : munin.Basic_Color.BrightBlue
	comp.draw_box_titled(buf, pos, width, 3, " Query ", .Rounded, color, .BrightWhite)
	model.query.is_focused = model.focus == .Query
	comp.draw_input(buf, {pos.x + 2, pos.y + 1}, model.query, width - 4, .Inline)
}

draw_results :: proc(buf: ^strings.Builder, model: Model, pos: munin.Vec2i, width, height: int) {
	color := model.focus == .Results ? munin.Basic_Color.BrightYellow : munin.Basic_Color.BrightBlue
	comp.draw_box_titled(buf, pos, width, height, " Results ", .Rounded, color, .BrightWhite)

	if len(model.result.error) > 0 {
		munin.print_at(buf, {pos.x + 2, pos.y + 2}, truncate(model.result.error, width - 4), .BrightRed)
		return
	}

	if len(model.result.columns) == 0 {
		munin.print_at(buf, {pos.x + 2, pos.y + 2}, "No result set", .BrightBlack)
		return
	}

	available_rows := max(1, height - 5)
	start := model.page * model.page_size
	end := min(start + min(model.page_size, available_rows), len(model.result.rows))

	columns := make([dynamic]comp.Table_Column, context.temp_allocator)
	col_width := max(8, (width - 4 - len(model.result.columns)) / max(1, len(model.result.columns)))
	for col in model.result.columns {
		append(&columns, comp.Table_Column{title = truncate(col, col_width), width = col_width, align = .Left})
	}

	rows := make([dynamic][]string, context.temp_allocator)
	for i in start ..< end {
		row := make([dynamic]string, context.temp_allocator)
		for cell in model.result.rows[i] {
			append(&row, truncate(cell, col_width))
		}
		append(&rows, row[:])
	}

	comp.draw_table(buf, {pos.x + 2, pos.y + 2}, columns[:], rows[:], .BrightCyan, .BrightBlack)

	total_pages := max(1, (len(model.result.rows) + model.page_size - 1) / model.page_size)
	page_text := fmt.tprintf("Page %d/%d  Rows %d-%d of %d", model.page + 1, total_pages, start + 1, end, len(model.result.rows))
	munin.print_at(buf, {pos.x + 2, pos.y + height - 2}, page_text, .BrightYellow)
}

draw_status :: proc(buf: ^strings.Builder, model: Model, pos: munin.Vec2i, width: int) {
	comp.draw_box_styled(buf, pos, width - 2, 3, .Single, .BrightBlack)
	controls := "Tab focus | Up/Down table | Enter run/load | Left/Right or PgUp/PgDn page | q quit"
	munin.print_at(buf, {pos.x + 2, pos.y + 1}, truncate(controls, width - 4), .BrightBlack)
	if len(model.status) > 0 {
		munin.print_at(buf, {pos.x + 2, pos.y}, truncate(model.status, width - 4), .BrightGreen)
	}
}

input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_key().?; ok {
		if event.key == .Char {
			if event.char == 'q' || event.char == 'Q' || event.char == 3 {
				return Quit{}
			}
			if event.char >= 32 {
				return AddChar{event.char}
			}
		}

		#partial switch event.key {
		case .Up:
			return PrevTable{}
		case .Down:
			return NextTable{}
		case .Tab:
			return NextFocus{}
		case .Enter:
			return RunQuery{}
		case .Backspace:
			return Backspace{}
		case .Left, .PageUp:
			return MoveLeft{}
		case .Right, .PageDown:
			return MoveRight{}
		case:
		}
	}
	return nil
}

set_query_text :: proc(input: ^comp.Input_State, text: string) {
	comp.input_clear(input)
	for r in text {
		comp.input_add_char(input, r)
	}
}

truncate :: proc(s: string, max_width: int) -> string {
	if max_width <= 0 {
		return ""
	}
	if munin.get_visible_width(s) <= max_width {
		return s
	}

	width := 0
	byte_pos := 0
	for r in s {
		rw := munin.rune_width(r)
		if width + rw > max_width - 1 {
			break
		}
		width += rw
		if r <= 0x7F {
			byte_pos += 1
		} else if r <= 0x7FF {
			byte_pos += 2
		} else if r <= 0xFFFF {
			byte_pos += 3
		} else {
			byte_pos += 4
		}
	}
	return fmt.tprintf("%s…", s[:byte_pos])
}

clear_strings :: proc(values: ^[dynamic]string) {
	for value in values {
		delete(value)
	}
	clear(values)
}

clear_result :: proc(result: ^Query_Result) {
	clear_strings(&result.columns)
	for &row in result.rows {
		clear_strings(&row)
		delete(row)
	}
	delete(result.rows)
	result.rows = nil
	if len(result.error) > 0 {
		delete(result.error)
		result.error = ""
	}
}

cleanup_model :: proc(model: ^Model) {
	if model.db != nil {
		sqlite3_close(model.db)
		model.db = nil
	}
	if len(model.db_path) > 0 {
		delete(model.db_path)
	}
	clear_strings(&model.tables)
	delete(model.tables)
	if model.query != nil {
		comp.destroy_input_state(model.query)
		free(model.query)
	}
	clear_result(&model.result)
	if len(model.schema) > 0 {
		delete(model.schema)
	}
	if len(model.status) > 0 {
		delete(model.status)
	}
}
