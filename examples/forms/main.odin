package main

import munin "../../munin"
import comp "../../munin/components"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:time"

// Global variables for cursor blinking timing
last_blink_time: time.Time
blink_initialized: bool

// Model holds the application state
Model :: struct {
	current_form:   int,
	focused_field:  int,
	message:        string,
	error_message:  string,
	show_success:   bool,
	show_results:   bool,
	results:        string,

	// Login form fields
	login_username: ^comp.Input_State,
	login_password: ^comp.Input_State,

	// Register form fields
	reg_username:   ^comp.Input_State,
	reg_email:      ^comp.Input_State,
	reg_password:   ^comp.Input_State,
	reg_confirm:    ^comp.Input_State,

	// Credit card form fields
	card_name:      ^comp.Input_State,
	card_number:    ^comp.Input_State,
	card_expiry:    ^comp.Input_State,
	card_cvv:       ^comp.Input_State,

	// Date form fields
	date_year:      ^comp.Input_State,
	date_month:     ^comp.Input_State,
	date_day:       ^comp.Input_State,

	// Chat form fields
	chat_message:   ^comp.Input_State,
	chat_history:   [dynamic]string,

	// Settings form fields
	setting_name:   ^comp.Input_State,
	setting_email:  ^comp.Input_State,
	setting_theme:  ^comp.Input_State,
}

init :: proc() -> Model {
	// Allocate input states
	login_username := new(comp.Input_State)
	login_password := new(comp.Input_State)
	reg_username := new(comp.Input_State)
	reg_email := new(comp.Input_State)
	reg_password := new(comp.Input_State)
	reg_confirm := new(comp.Input_State)
	card_name := new(comp.Input_State)
	card_number := new(comp.Input_State)
	card_expiry := new(comp.Input_State)
	card_cvv := new(comp.Input_State)
	date_year := new(comp.Input_State)
	date_month := new(comp.Input_State)
	date_day := new(comp.Input_State)
	chat_message := new(comp.Input_State)
	setting_name := new(comp.Input_State)
	setting_email := new(comp.Input_State)
	setting_theme := new(comp.Input_State)

	// Initialize input states
	login_username^ = comp.make_input_state(32, "Enter username")
	login_password^ = comp.make_input_state(32, "Enter password")
	reg_username^ = comp.make_input_state(32, "Enter username")
	reg_email^ = comp.make_input_state(64, "Enter email address")
	reg_password^ = comp.make_input_state(32, "Enter password")
	reg_confirm^ = comp.make_input_state(32, "Confirm password")
	card_name^ = comp.make_input_state(50, "Name on card")
	card_number^ = comp.make_input_state(19, "1234 5678 9012 3456")
	card_expiry^ = comp.make_input_state(5, "MM/YY")
	card_cvv^ = comp.make_input_state(3, "CVV")
	date_year^ = comp.make_input_state(4, "YYYY")
	date_month^ = comp.make_input_state(2, "MM")
	date_day^ = comp.make_input_state(2, "DD")
	chat_message^ = comp.make_input_state(200, "Type your message...")
	setting_name^ = comp.make_input_state(50, "Your name")
	setting_email^ = comp.make_input_state(64, "Your email")
	setting_theme^ = comp.make_input_state(20, "dark/light")

	// Set password fields
	login_password.is_password = true
	reg_password.is_password = true
	reg_confirm.is_password = true
	card_cvv.is_password = true

	model := Model {
		current_form   = 0,
		focused_field  = 0,
		message        = "Login Form. Navigate with TAB/Arrows, submit with ENTER, quit with ctrl+c.",
		error_message  = "",
		show_success   = false,
		show_results   = false,
		results        = "",
		login_username = login_username,
		login_password = login_password,
		reg_username   = reg_username,
		reg_email      = reg_email,
		reg_password   = reg_password,
		reg_confirm    = reg_confirm,
		card_name      = card_name,
		card_number    = card_number,
		card_expiry    = card_expiry,
		card_cvv       = card_cvv,
		date_year      = date_year,
		date_month     = date_month,
		date_day       = date_day,
		chat_message   = chat_message,
		chat_history   = make([dynamic]string),
		setting_name   = setting_name,
		setting_email  = setting_email,
		setting_theme  = setting_theme,
	}

	return model
}

// Messages define all possible events
SubmitForm :: struct {}
NextForm :: struct {}
PrevForm :: struct {}
NextField :: struct {}
PrevField :: struct {}
ShiftTab :: struct {}
AddChar :: struct {
	char: rune,
}
Backspace :: struct {}
Delete :: struct {}
ClearError :: struct {}
AddChatMessage :: struct {}
SwitchToForm :: struct {
	form_index: int,
}
Quit :: struct {}
LeftArrow :: struct {}
RightArrow :: struct {}
BlinkCursor :: struct {}

Msg :: union {
	SubmitForm,
	NextForm,
	PrevForm,
	NextField,
	PrevField,
	ShiftTab,
	AddChar,
	Backspace,
	Delete,
	ClearError,
	AddChatMessage,
	SwitchToForm,
	Quit,
	LeftArrow,
	RightArrow,
	BlinkCursor,
}

// Update handles state transitions
update :: proc(msg: Msg, model: Model) -> (Model, bool) {
	new_model := model
	should_quit := false

	switch m in msg {
	case SubmitForm:
		if validate_and_submit(&new_model) {
			new_model.show_success = true
			new_model.show_results = true
			new_model.error_message = ""
		}
	case NextForm:
		new_model.current_form = (model.current_form + 1) % 6
		new_model.focused_field = 0
		new_model.message = get_form_message(new_model.current_form)
		new_model.error_message = ""
		new_model.show_success = false
		new_model.show_results = false
		new_model.results = ""
	case PrevForm:
		new_model.current_form = (model.current_form - 1 + 6) % 6
		new_model.focused_field = 0
		new_model.message = get_form_message(new_model.current_form)
		new_model.error_message = ""
		new_model.show_success = false
		new_model.show_results = false
		new_model.results = ""
	case NextField:
		field_count := get_field_count(model.current_form)
		new_model.focused_field = (model.focused_field + 1) % field_count
	case PrevField:
		field_count := get_field_count(model.current_form)
		new_model.focused_field = (model.focused_field - 1 + field_count) % field_count
	case ShiftTab:
		field_count := get_field_count(model.current_form)
		new_model.focused_field = (model.focused_field - 1 + field_count) % field_count
	case AddChar:
		add_char_to_field(&new_model, m.char)
		new_model.show_success = false
		new_model.show_results = false
		new_model.results = ""
	case Backspace:
		backspace_field(&new_model)
		new_model.show_success = false
		new_model.show_results = false
		new_model.results = ""
	case Delete:
		delete_field(&new_model)
		new_model.show_success = false
		new_model.show_results = false
		new_model.results = ""
	case ClearError:
		new_model.error_message = ""
	case AddChatMessage:
		if len(new_model.chat_message.buffer) > 0 {
			msg_text := comp.input_get_text(new_model.chat_message)
			append(&new_model.chat_history, msg_text)
			comp.input_clear(new_model.chat_message)
		}
	case SwitchToForm:
		new_model.current_form = m.form_index % 6
		new_model.focused_field = 0
		new_model.message = get_form_message(new_model.current_form)
		new_model.error_message = ""
		new_model.show_success = false
	case Quit:
		should_quit = true
	case LeftArrow:
		new_model.current_form = (model.current_form - 1 + 6) % 6
		new_model.focused_field = 0
		new_model.message = get_form_message(new_model.current_form)
		new_model.error_message = ""
		new_model.show_success = false
		new_model.show_results = false
		new_model.results = ""
	case RightArrow:
		new_model.current_form = (model.current_form + 1) % 6
		new_model.focused_field = 0
		new_model.message = get_form_message(new_model.current_form)
		new_model.error_message = ""
		new_model.show_success = false
		new_model.show_results = false
		new_model.results = ""
	case BlinkCursor:
		// Toggle cursor blink state for all input fields
		comp.input_toggle_cursor_blink(new_model.login_username)
		comp.input_toggle_cursor_blink(new_model.login_password)
		comp.input_toggle_cursor_blink(new_model.reg_username)
		comp.input_toggle_cursor_blink(new_model.reg_email)
		comp.input_toggle_cursor_blink(new_model.reg_password)
		comp.input_toggle_cursor_blink(new_model.reg_confirm)
		comp.input_toggle_cursor_blink(new_model.card_name)
		comp.input_toggle_cursor_blink(new_model.card_number)
		comp.input_toggle_cursor_blink(new_model.card_expiry)
		comp.input_toggle_cursor_blink(new_model.card_cvv)
		comp.input_toggle_cursor_blink(new_model.date_year)
		comp.input_toggle_cursor_blink(new_model.date_month)
		comp.input_toggle_cursor_blink(new_model.date_day)
		comp.input_toggle_cursor_blink(new_model.chat_message)
		comp.input_toggle_cursor_blink(new_model.setting_name)
		comp.input_toggle_cursor_blink(new_model.setting_email)
		comp.input_toggle_cursor_blink(new_model.setting_theme)
	}

	return new_model, should_quit
}

// Subscription for cursor blinking
subscriptions :: proc(model: Model) -> Maybe(Msg) {
	// Check if enough time has passed for cursor blink
	if !blink_initialized {
		last_blink_time = time.now()
		blink_initialized = true
	}

	current_time := time.now()
	elapsed_ms := time.diff(last_blink_time, current_time) / time.Millisecond

	if elapsed_ms >= 500 { 	// Blink every 500ms
		last_blink_time = current_time
		return BlinkCursor{}
	}

	return nil
}

get_form_message :: proc(form_index: int) -> string {
	messages := []string {
		"Login Form. Use TAB/↓ for next field, ↑ for previous field.",
		"Registration Form. All fields are required.",
		"Credit Card Payment Form. Enter card details.",
		"Date Selection Form. Choose a date.",
		"Chat Interface. Type message and press ENTER to send.",
		"Settings Form. Update your preferences.",
	}
	return messages[form_index]
}

get_field_count :: proc(form_index: int) -> int {
	counts := []int{2, 4, 4, 3, 1, 3}
	return counts[form_index]
}

add_char_to_field :: proc(model: ^Model, char: rune) {
	switch model.current_form {
	case 0:
		// Login
		if model.focused_field == 0 {
			comp.input_add_char(model.login_username, char)
		} else {
			comp.input_add_char(model.login_password, char)
		}
	case 1:
		// Register
		switch model.focused_field {
		case 0:
			comp.input_add_char(model.reg_username, char)
		case 1:
			comp.input_add_char(model.reg_email, char)
		case 2:
			comp.input_add_char(model.reg_password, char)
		case 3:
			comp.input_add_char(model.reg_confirm, char)
		}
	case 2:
		// Credit Card
		switch model.focused_field {
		case 0:
			comp.input_add_char(model.card_name, char)
		case 1:
			comp.input_add_char(model.card_number, char)
		case 2:
			comp.input_add_char(model.card_expiry, char)
		case 3:
			comp.input_add_char(model.card_cvv, char)
		}
	case 3:
		// Date
		switch model.focused_field {
		case 0:
			comp.input_add_char(model.date_year, char)
		case 1:
			comp.input_add_char(model.date_month, char)
		case 2:
			comp.input_add_char(model.date_day, char)
		}
	case 4:
		// Chat
		comp.input_add_char(model.chat_message, char)
	case 5:
		// Settings
		switch model.focused_field {
		case 0:
			comp.input_add_char(model.setting_name, char)
		case 1:
			comp.input_add_char(model.setting_email, char)
		case 2:
			comp.input_add_char(model.setting_theme, char)
		}
	}
}

backspace_field :: proc(model: ^Model) {
	switch model.current_form {
	case 0:
		// Login
		if model.focused_field == 0 {
			comp.input_backspace(model.login_username)
		} else {
			comp.input_backspace(model.login_password)
		}
	case 1:
		// Register
		switch model.focused_field {
		case 0:
			comp.input_backspace(model.reg_username)
		case 1:
			comp.input_backspace(model.reg_email)
		case 2:
			comp.input_backspace(model.reg_password)
		case 3:
			comp.input_backspace(model.reg_confirm)
		}
	case 2:
		// Credit Card
		switch model.focused_field {
		case 0:
			comp.input_backspace(model.card_name)
		case 1:
			comp.input_backspace(model.card_number)
		case 2:
			comp.input_backspace(model.card_expiry)
		case 3:
			comp.input_backspace(model.card_cvv)
		}
	case 3:
		// Date
		switch model.focused_field {
		case 0:
			comp.input_backspace(model.date_year)
		case 1:
			comp.input_backspace(model.date_month)
		case 2:
			comp.input_backspace(model.date_day)
		}
	case 4:
		// Chat
		comp.input_backspace(model.chat_message)
	case 5:
		// Settings
		switch model.focused_field {
		case 0:
			comp.input_backspace(model.setting_name)
		case 1:
			comp.input_backspace(model.setting_email)
		case 2:
			comp.input_backspace(model.setting_theme)
		}
	}
}

delete_field :: proc(model: ^Model) {
	switch model.current_form {
	case 0:
		// Login
		if model.focused_field == 0 {
			comp.input_delete(model.login_username)
		} else {
			comp.input_delete(model.login_password)
		}
	case 1:
		// Register
		switch model.focused_field {
		case 0:
			comp.input_delete(model.reg_username)
		case 1:
			comp.input_delete(model.reg_email)
		case 2:
			comp.input_delete(model.reg_password)
		case 3:
			comp.input_delete(model.reg_confirm)
		}
	case 2:
		// Credit Card
		switch model.focused_field {
		case 0:
			comp.input_delete(model.card_name)
		case 1:
			comp.input_delete(model.card_number)
		case 2:
			comp.input_delete(model.card_expiry)
		case 3:
			comp.input_delete(model.card_cvv)
		}
	case 3:
		// Date
		switch model.focused_field {
		case 0:
			comp.input_delete(model.date_year)
		case 1:
			comp.input_delete(model.date_month)
		case 2:
			comp.input_delete(model.date_day)
		}
	case 4:
		// Chat
		comp.input_delete(model.chat_message)
	case 5:
		// Settings
		switch model.focused_field {
		case 0:
			comp.input_delete(model.setting_name)
		case 1:
			comp.input_delete(model.setting_email)
		case 2:
			comp.input_delete(model.setting_theme)
		}
	}
}

validate_and_submit :: proc(model: ^Model) -> bool {
	model.error_message = ""

	switch model.current_form {
	case 0:
		// Login
		if comp.input_is_empty(model.login_username) {
			model.error_message = "Username is required"
			return false
		}
		if comp.input_is_empty(model.login_password) {
			model.error_message = "Password is required"
			return false
		}
		// Generate results
		username := comp.input_get_text(model.login_username)
		model.results = fmt.tprintf(
			"✓ Login successful!\n  Username: %s\n  Session: Active",
			username,
		)
		return true

	case 1:
		// Register
		if comp.input_is_empty(model.reg_username) {
			model.error_message = "Username is required"
			return false
		}
		if !comp.input_is_valid_email(model.reg_email) {
			model.error_message = "Valid email is required"
			return false
		}
		if comp.input_get_length(model.reg_password) < 8 {
			model.error_message = "Password must be at least 8 characters"
			return false
		}
		if comp.input_get_text(model.reg_password) != comp.input_get_text(model.reg_confirm) {
			model.error_message = "Passwords do not match"
			return false
		}
		// Generate results
		username := comp.input_get_text(model.reg_username)
		email := comp.input_get_text(model.reg_email)
		model.results = fmt.tprintf(
			"✓ Registration complete!\n  Username: %s\n  Email: %s\n  Status: Verified",
			username,
			email,
		)
		return true

	case 2:
		// Credit Card
		if comp.input_is_empty(model.card_name) {
			model.error_message = "Cardholder name is required"
			return false
		}
		card_text := comp.input_get_text(model.card_number)
		card_len := 0
		for char in card_text {
			if char != ' ' {
				card_len += 1
			}
		}
		if card_len < 16 {
			model.error_message = "Invalid card number"
			return false
		}
		// Generate results
		name := comp.input_get_text(model.card_name)
		expiry := comp.input_get_text(model.card_expiry)
		last4 := card_text[len(card_text) - 4:]
		model.results = fmt.tprintf(
			"✓ Payment processed!\n  Cardholder: %s\n  Card: ****-%s\n  Expiry: %s\n  Status: Approved",
			name,
			last4,
			expiry,
		)
		return true

	case 3:
		// Date
		if comp.input_get_length(model.date_year) != 4 {
			model.error_message = "Invalid year"
			return false
		}
		// Generate results
		year := comp.input_get_text(model.date_year)
		month := comp.input_get_text(model.date_month)
		day := comp.input_get_text(model.date_day)
		model.results = fmt.tprintf(
			"✓ Date selected!\n  Date: %s/%s/%s\n  Format: MM/DD/YYYY\n  Validated: Yes",
			month,
			day,
			year,
		)
		return true

	case 4:
		// Chat
		if len(model.chat_history) > 0 {
			// Generate results
			msg_count := len(model.chat_history)
			model.results = fmt.tprintf(
				"✓ Chat session active!\n  Messages: %d\n  Latest: %s\n  Status: Connected",
				msg_count,
				model.chat_history[msg_count - 1],
			)
		} else {
			model.results = "✓ Chat session started!\n  Messages: 0\n  Status: Ready\n  Type a message to begin"
		}
		return true

	case 5:
		// Settings
		if comp.input_is_empty(model.setting_name) {
			model.error_message = "Name is required"
			return false
		}
		// Generate results
		name := comp.input_get_text(model.setting_name)
		email := comp.input_get_text(model.setting_email)
		theme := comp.input_get_text(model.setting_theme)
		model.results = fmt.tprintf(
			"✓ Settings saved!\n  Name: %s\n  Email: %s\n  Theme: %s\n  Updated: Just now",
			name,
			email,
			theme,
		)
		return true
	}

	return false
}

// Update field focus states based on current form and focused field
update_field_focus_states :: proc(model: ^Model) {
	// First, clear all focus states
	model.login_username.is_focused = false
	model.login_password.is_focused = false
	model.reg_username.is_focused = false
	model.reg_email.is_focused = false
	model.reg_password.is_focused = false
	model.reg_confirm.is_focused = false
	model.card_name.is_focused = false
	model.card_number.is_focused = false
	model.card_expiry.is_focused = false
	model.card_cvv.is_focused = false
	model.date_year.is_focused = false
	model.date_month.is_focused = false
	model.date_day.is_focused = false
	model.chat_message.is_focused = false
	model.setting_name.is_focused = false
	model.setting_email.is_focused = false
	model.setting_theme.is_focused = false

	// Set focus for current form and field
	switch model.current_form {
	case 0:
		// Login
		if model.focused_field == 0 {
			model.login_username.is_focused = true
		} else {
			model.login_password.is_focused = true
		}
	case 1:
		// Register
		switch model.focused_field {
		case 0:
			model.reg_username.is_focused = true
		case 1:
			model.reg_email.is_focused = true
		case 2:
			model.reg_password.is_focused = true
		case 3:
			model.reg_confirm.is_focused = true
		}
	case 2:
		// Credit Card
		switch model.focused_field {
		case 0:
			model.card_name.is_focused = true
		case 1:
			model.card_number.is_focused = true
		case 2:
			model.card_expiry.is_focused = true
		case 3:
			model.card_cvv.is_focused = true
		}
	case 3:
		// Date
		switch model.focused_field {
		case 0:
			model.date_year.is_focused = true
		case 1:
			model.date_month.is_focused = true
		case 2:
			model.date_day.is_focused = true
		}
	case 4:
		// Chat
		model.chat_message.is_focused = true
	case 5:
		// Settings
		switch model.focused_field {
		case 0:
			model.setting_name.is_focused = true
		case 1:
			model.setting_email.is_focused = true
		case 2:
			model.setting_theme.is_focused = true
		}
	}
}

// View renders the current state
view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)

	// Set window title
	munin.set_window_title(buf, "Munin Input Forms Demo")

	// Header
	title := "Interactive Form Examples"
	munin.draw_title(buf, {0, 1}, 80, title, .BrightCyan)

	// Form navigation - equal spaced menu considering text lengths
	munin.print_at(buf, {2, 3}, "Forms:", .BrightWhite)
	forms := []string{"Login", "Register", "CreditCard", "Date", "Chat", "Settings"}

	// Calculate positions for equal spacing between centers considering text lengths
	total_forms := len(forms)
	margin := 11 // Margin from edges
	available_width := 80 - 2 * margin

	// Calculate positions for equal spacing between item centers
	positions := make([dynamic]int, total_forms)
	defer delete(positions)

	for i in 0 ..< total_forms {
		// Position center of each item at equal intervals
		center_pos := margin + (i * available_width) / (total_forms - 1)
		// Calculate item start position by subtracting half its length including brackets
		item_text := forms[i]
		item_with_brackets := fmt.tprintf("[%s]", item_text)
		item_len := len(item_with_brackets)
		start_pos := center_pos - item_len / 2
		positions[i] = start_pos // Direct assignment
	}

	for i in 0 ..< len(forms) {
		color := munin.Basic_Color.White
		if i == model.current_form {
			color = .BrightYellow
		}
		item_display := fmt.tprintf("[%s]", forms[i])
		munin.print_at(buf, {positions[i], 3}, item_display, color)
	}

	// Current form description - centered
	desc_x := max(2, (80 - len(model.message)) / 2)
	munin.print_at(buf, {desc_x, 5}, model.message, .BrightGreen)

	// Create a mutable copy for focus state updates
	mutable_model := model
	update_field_focus_states(&mutable_model)

	// Draw current form
	form_y := 8
	switch mutable_model.current_form {
	case 0:
		draw_login_form(buf, {20, form_y}, mutable_model) // Center, width 40
	case 1:
		draw_register_form(buf, {15, form_y}, mutable_model) // Center, width 50
	case 2:
		draw_credit_card_form(buf, {0, form_y}, mutable_model) // Left edge, width 60
	case 3:
		draw_date_form(buf, {65, form_y}, mutable_model) // Right edge, width 30
	case 4:
		draw_chat_form(buf, {5, form_y}, mutable_model) // Left, width 70
	case 5:
		draw_settings_form(buf, {18, form_y}, mutable_model) // Center, width 40
	}

	// Message area - ensure proper spacing
	message_y := max(form_y + 22, 20) // Place after forms but at least at row 20

	// Show error message if any
	if len(mutable_model.error_message) > 0 {
		munin.print_at(
			buf,
			{2, message_y},
			fmt.tprintf("Error: %s", mutable_model.error_message),
			.BrightRed,
		)
		message_y += 1
	}

	// Show success message if any (only if no error)
	if mutable_model.show_success && len(mutable_model.error_message) == 0 {
		munin.print_at(buf, {2, message_y}, "Form submitted successfully!", .BrightGreen)
		message_y += 1
	}

	// Show detailed results if available
	if mutable_model.show_results && len(mutable_model.results) > 0 {
		munin.print_at(buf, {2, message_y}, "─ Results ─", .BrightCyan)
		message_y += 1

		// Split results by newline and display each line
		results_text := mutable_model.results
		lines := strings.split(results_text, "\n")
		for line in lines {
			if len(line) > 0 {
				munin.print_at(buf, {4, message_y}, line, .BrightWhite)
				message_y += 1
			}
		}
		message_y += 1 // Extra spacing after results
	}

	// Instructions at bottom - ensure no overlap
	instructions_y := max(message_y + 1, 22) // Start at least at row 22, or after messages
	munin.print_at(buf, {2, instructions_y}, "Controls:", .BrightWhite)
	munin.print_at(
		buf,
		{2, instructions_y + 1},
		"  ← → : Switch forms | 1-6 : Jump to form",
		.White,
	)
	munin.print_at(
		buf,
		{2, instructions_y + 2},
		"  TAB/↓ : Next field | ↑/SHIFT+TAB : Previous field",
		.White,
	)
	munin.print_at(
		buf,
		{2, instructions_y + 3},
		"  ENTER : Submit & show results | Q : Quit",
		.White,
	)
}

draw_login_form :: proc(buf: ^strings.Builder, pos: munin.Vec2i, model: Model) {
	comp.draw_box_styled(buf, pos, 40, 12, .Rounded, .BrightBlue)
	munin.print_at(buf, {pos.x + 15, pos.y + 1}, "LOGIN", .BrightWhite)

	// Username label
	munin.print_at(buf, {pos.x + 3, pos.y + 3}, "Username:", .BrightYellow)
	// Username field
	comp.draw_input(
		buf,
		{pos.x + 3, pos.y + 4},
		model.login_username,
		34,
		.Plain,
		"",
		.BrightYellow,
		.White,
		.BrightGreen,
		.BrightBlue,
	)

	// Password label
	munin.print_at(buf, {pos.x + 3, pos.y + 8}, "Password:", .BrightYellow)
	// Password field
	comp.draw_input(
		buf,
		{pos.x + 3, pos.y + 9},
		model.login_password,
		34,
		.Plain,
		"",
		.BrightYellow,
		.White,
		.BrightGreen,
		.BrightBlue,
	)
}

draw_register_form :: proc(buf: ^strings.Builder, pos: munin.Vec2i, model: Model) {
	comp.draw_box_styled(buf, pos, 50, 20, .Rounded, .BrightMagenta)
	munin.print_at(buf, {pos.x + 18, pos.y + 1}, "REGISTER", .BrightWhite)

	// Username label
	munin.print_at(buf, {pos.x + 3, pos.y + 3}, "Username:", .BrightYellow)
	// Username field
	comp.draw_input(
		buf,
		{pos.x + 3, pos.y + 4},
		model.reg_username,
		44,
		.Plain,
		"",
		.BrightYellow,
		.White,
		.BrightGreen,
		.BrightBlue,
	)

	// Email label
	munin.print_at(buf, {pos.x + 3, pos.y + 7}, "Email:", .BrightYellow)
	// Email field
	comp.draw_input(
		buf,
		{pos.x + 3, pos.y + 8},
		model.reg_email,
		44,
		.Plain,
		"",
		.BrightYellow,
		.White,
		.BrightGreen,
		.BrightBlue,
	)

	// Password label
	munin.print_at(buf, {pos.x + 3, pos.y + 11}, "Password:", .BrightYellow)
	// Password field
	comp.draw_input(
		buf,
		{pos.x + 3, pos.y + 12},
		model.reg_password,
		44,
		.Plain,
		"",
		.BrightYellow,
		.White,
		.BrightGreen,
		.BrightBlue,
	)

	// Confirm label
	munin.print_at(buf, {pos.x + 3, pos.y + 15}, "Confirm:", .BrightYellow)
	// Confirm field
	comp.draw_input(
		buf,
		{pos.x + 3, pos.y + 16},
		model.reg_confirm,
		44,
		.Plain,
		"",
		.BrightYellow,
		.White,
		.BrightGreen,
		.BrightBlue,
	)
}

draw_credit_card_form :: proc(buf: ^strings.Builder, pos: munin.Vec2i, model: Model) {
	comp.draw_box_styled(buf, pos, 60, 18, .Rounded, .BrightGreen)
	munin.print_at(buf, {pos.x + 20, pos.y + 1}, "PAYMENT", .BrightWhite)

	// Cardholder label
	munin.print_at(buf, {pos.x + 3, pos.y + 3}, "Cardholder:", .BrightYellow)
	// Cardholder name field
	comp.draw_input(
		buf,
		{pos.x + 3, pos.y + 4},
		model.card_name,
		54,
		.Plain,
		"",
		.BrightYellow,
		.White,
		.BrightGreen,
		.BrightBlue,
	)

	// Card number label
	munin.print_at(buf, {pos.x + 3, pos.y + 7}, "Card Number:", .BrightYellow)
	// Card number field
	comp.draw_input(
		buf,
		{pos.x + 3, pos.y + 8},
		model.card_number,
		54,
		.Plain,
		"",
		.BrightYellow,
		.White,
		.BrightGreen,
		.BrightBlue,
	)

	// Expiry label
	munin.print_at(buf, {pos.x + 3, pos.y + 11}, "Expiry (MM/YY):", .BrightYellow)
	// Expiry field
	comp.draw_input(
		buf,
		{pos.x + 3, pos.y + 12},
		model.card_expiry,
		20,
		.Plain,
		"",
		.BrightYellow,
		.White,
		.BrightGreen,
		.BrightBlue,
	)

	// CVV label
	munin.print_at(buf, {pos.x + 35, pos.y + 11}, "CVV:", .BrightYellow)
	// CVV field
	comp.draw_input(
		buf,
		{pos.x + 35, pos.y + 12},
		model.card_cvv,
		22,
		.Plain,
		"",
		.BrightYellow,
		.White,
		.BrightGreen,
		.BrightBlue,
	)
}

draw_date_form :: proc(buf: ^strings.Builder, pos: munin.Vec2i, model: Model) {
	comp.draw_box_styled(buf, pos, 30, 16, .Rounded, .BrightYellow)
	munin.print_at(buf, {pos.x + 10, pos.y + 1}, "DATE", .BrightWhite)

	// Year label
	munin.print_at(buf, {pos.x + 3, pos.y + 3}, "Year:", .BrightYellow)
	// Year field
	comp.draw_input(
		buf,
		{pos.x + 3, pos.y + 4},
		model.date_year,
		24,
		.Plain,
		"",
		.BrightYellow,
		.White,
		.BrightGreen,
		.BrightBlue,
	)

	// Month label
	munin.print_at(buf, {pos.x + 3, pos.y + 7}, "Month:", .BrightYellow)
	// Month field
	comp.draw_input(
		buf,
		{pos.x + 3, pos.y + 8},
		model.date_month,
		24,
		.Plain,
		"",
		.BrightYellow,
		.White,
		.BrightGreen,
		.BrightBlue,
	)

	// Day label
	munin.print_at(buf, {pos.x + 3, pos.y + 11}, "Day:", .BrightYellow)
	// Day field
	comp.draw_input(
		buf,
		{pos.x + 3, pos.y + 12},
		model.date_day,
		24,
		.Plain,
		"",
		.BrightYellow,
		.White,
		.BrightGreen,
		.BrightBlue,
	)
}

draw_chat_form :: proc(buf: ^strings.Builder, pos: munin.Vec2i, model: Model) {
	comp.draw_box_styled(buf, pos, 70, 20, .Rounded, .BrightCyan)
	munin.print_at(buf, {pos.x + 28, pos.y + 1}, "CHAT", .BrightWhite)

	// Chat history area
	munin.print_at(buf, {pos.x + 2, pos.y + 3}, "Messages:", .BrightWhite)
	history_y := pos.y + 4
	history_count := min(len(model.chat_history), 10)
	for i in 0 ..< history_count {
		msg_index := len(model.chat_history) - history_count + i
		munin.print_at(
			buf,
			{pos.x + 2, history_y + i},
			fmt.tprintf("> %s", model.chat_history[msg_index]),
			.BrightBlack,
		)
	}

	// Input field label
	munin.print_at(buf, {pos.x + 2, pos.y + 14}, "Message:", .BrightYellow)
	// Input field
	comp.draw_input(
		buf,
		{pos.x + 2, pos.y + 15},
		model.chat_message,
		66,
		.Plain,
		"",
		.BrightYellow,
		.White,
		.BrightGreen,
		.BrightBlue,
	)
}

draw_settings_form :: proc(buf: ^strings.Builder, pos: munin.Vec2i, model: Model) {
	comp.draw_box_styled(buf, pos, 40, 18, .Rounded, .BrightRed)
	munin.print_at(buf, {pos.x + 13, pos.y + 1}, "SETTINGS", .BrightWhite)

	// Name label
	munin.print_at(buf, {pos.x + 3, pos.y + 3}, "Name:", .BrightYellow)
	// Name field
	comp.draw_input(
		buf,
		{pos.x + 3, pos.y + 4},
		model.setting_name,
		34,
		.Plain,
		"",
		.BrightYellow,
		.White,
		.BrightGreen,
		.BrightBlue,
	)

	// Email label
	munin.print_at(buf, {pos.x + 3, pos.y + 7}, "Email:", .BrightYellow)
	// Email field
	comp.draw_input(
		buf,
		{pos.x + 3, pos.y + 8},
		model.setting_email,
		34,
		.Plain,
		"",
		.BrightYellow,
		.White,
		.BrightGreen,
		.BrightBlue,
	)

	// Theme label
	munin.print_at(buf, {pos.x + 3, pos.y + 11}, "Theme:", .BrightYellow)
	// Theme field
	comp.draw_input(
		buf,
		{pos.x + 3, pos.y + 12},
		model.setting_theme,
		34,
		.Plain,
		"",
		.BrightYellow,
		.White,
		.BrightGreen,
		.BrightBlue,
	)
}

// Input handler processes keyboard events
input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_key().?; ok {
		#partial switch event.key {
		case .Escape:
			return Quit{}
		case .Enter:
			return SubmitForm{}
		case .Tab:
			// Note: Shift+Tab detection is unreliable on many terminals
			// Both Tab and Shift+Tab often send the same byte (ASCII 9)
			if event.shift {
				return ShiftTab{}
			} else {
				return NextField{}
			}
		case .Up:
			// Use Up arrow for previous field navigation
			return ShiftTab{}
		case .Down:
			// Use Down arrow for next field navigation
			return NextField{}
		case .Char:
			if event.ctrl && event.char == 'c' {
				return Quit{}
			} else if event.char == 3 {
				return Quit{}
			} else if event.char == '1' {
				return SwitchToForm{0}
			} else if event.char == '2' {
				return SwitchToForm{1}
			} else if event.char == '3' {
				return SwitchToForm{2}
			} else if event.char == '4' {
				return SwitchToForm{3}
			} else if event.char == '5' {
				return SwitchToForm{4}
			} else if event.char == '6' {
				return SwitchToForm{5}
			} else if event.char >= 32 {
				return AddChar{event.char}
			}
		case .Left:
			return LeftArrow{}
		case .Right:
			return RightArrow{}
		case .Backspace:
			return Backspace{}
		}
	}
	return nil
}

main :: proc() {
	// Debug-time memory tracking
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

	// Create and run program with subscriptions for cursor blinking
	program := munin.make_program_with_subs(init, update, view, subscriptions)
	munin.run(&program, input_handler, target_fps = 60)
}
