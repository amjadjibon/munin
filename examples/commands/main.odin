package main

// Commands: scheduling work instead of polling for it.
//
// An update that takes a ^munin.Cmd_Context(Msg) can answer a message with
// "and then do this":
//
//	cmd_every  - repeat a message on an interval   (the clock below)
//	cmd_after  - deliver a message once, later     (the toast, the pipeline)
//	cmd_send   - deliver a message next iteration  (chaining steps)
//	cmd_cancel - stop a scheduled or repeating one (pausing the clock)
//	cmd_quit   - stop the program
//
// The alternative is a subscription that runs every loop iteration and
// compares clocks against file-scope globals. The runtime knows when the next
// message is due; the application should not have to.

import munin "../../munin"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:time"

// ============================================================
// MODEL
// ============================================================

Step :: enum {
	Idle,
	Fetching,
	Building,
	Testing,
	Done,
}

Model :: struct {
	// A clock ticking once a second, driven by cmd_every.
	seconds:      int,
	clock:        munin.Cmd_Handle,
	clock_paused: bool,

	// A fake build pipeline: each step schedules the next one.
	step:         Step,
	log:          [dynamic]string,

	// A message that clears itself after a while, via cmd_after.
	toast:        string,
}

init :: proc() -> Model {
	return Model{step = .Idle, log = make([dynamic]string)}
}

destroy_model :: proc(model: ^Model) {
	for line in model.log {
		delete(line)
	}
	delete(model.log)
}

// ============================================================
// MESSAGES
// ============================================================

Tick :: struct {}
Toggle_Clock :: struct {}
Start_Pipeline :: struct {}
Advance :: struct {
	to: Step,
}
Show_Toast :: struct {
	text: string,
}
Clear_Toast :: struct {}
Quit :: struct {}

Msg :: union {
	Tick,
	Toggle_Clock,
	Start_Pipeline,
	Advance,
	Show_Toast,
	Clear_Toast,
	Quit,
}

// ============================================================
// UPDATE
// ============================================================

@(private = "file")
log_line :: proc(model: ^Model, text: string) {
	append(&model.log, strings.clone(text))
	if len(model.log) > 8 {
		delete(model.log[0])
		ordered_remove(&model.log, 0)
	}
}

update :: proc(msg: Msg, model: Model, cmds: ^munin.Cmd_Context(Msg)) -> Model {
	m := model

	switch e in msg {
	case Tick:
		m.seconds += 1

	case Toggle_Clock:
		if m.clock_paused {
			// Start it again and remember the new handle.
			m.clock = munin.cmd_every(cmds, time.Second, Msg(Tick{}))
			m.clock_paused = false
			munin.cmd_send(cmds, Msg(Show_Toast{"clock resumed"}))
		} else {
			munin.cmd_cancel(cmds, m.clock)
			m.clock_paused = true
			munin.cmd_send(cmds, Msg(Show_Toast{"clock paused"}))
		}

	case Start_Pipeline:
		if m.step != .Idle && m.step != .Done {
			munin.cmd_send(cmds, Msg(Show_Toast{"already running"}))
			break
		}
		clear(&m.log)
		m.step = .Fetching
		log_line(&m, "fetching sources...")
		// Each step hands off to the next after a delay, without the update
		// function ever blocking.
		munin.cmd_after(cmds, 700 * time.Millisecond, Msg(Advance{.Building}))

	case Advance:
		m.step = e.to
		switch e.to {
		case .Building:
			log_line(&m, "compiling...")
			munin.cmd_after(cmds, 900 * time.Millisecond, Msg(Advance{.Testing}))
		case .Testing:
			log_line(&m, "running tests...")
			munin.cmd_after(cmds, 600 * time.Millisecond, Msg(Advance{.Done}))
		case .Done:
			log_line(&m, "done.")
			munin.cmd_send(cmds, Msg(Show_Toast{"pipeline finished"}))
		case .Idle, .Fetching:
		// not scheduled
		}

	case Show_Toast:
		m.toast = e.text
		// Clear it after two seconds. Scheduling replaces the old timer's
		// effect naturally: the newest one simply arrives last.
		munin.cmd_after(cmds, 2 * time.Second, Msg(Clear_Toast{}))

	case Clear_Toast:
		m.toast = ""

	case Quit:
		munin.cmd_quit(cmds)
	}

	return m
}

// ============================================================
// VIEW
// ============================================================

step_label :: proc(step: Step) -> (string, munin.Color) {
	switch step {
	case .Idle:
		return "idle", munin.Basic_Color.BrightBlack
	case .Fetching:
		return "fetching", munin.Basic_Color.BrightYellow
	case .Building:
		return "building", munin.Basic_Color.BrightYellow
	case .Testing:
		return "testing", munin.Basic_Color.BrightCyan
	case .Done:
		return "done", munin.Basic_Color.BrightGreen
	}
	return "", munin.Basic_Color.White
}

view :: proc(model: Model, buf: ^strings.Builder) {
	munin.clear_screen(buf)

	munin.set_bold(buf)
	munin.print_at(buf, {2, 1}, "Commands", .BrightCyan)
	munin.reset_style(buf)
	munin.print_at(buf, {2, 2}, "scheduled messages instead of per-frame polling", .BrightBlack)

	// cmd_every
	clock_state := model.clock_paused ? "paused" : "running"
	munin.print_at(buf, {2, 4}, "cmd_every(1s)", .BrightYellow)
	munin.print_at(
		buf,
		{20, 4},
		fmt.tprintf("%3d seconds elapsed  (%s)", model.seconds, clock_state),
		.White,
	)

	// cmd_after / cmd_send
	label, color := step_label(model.step)
	munin.print_at(buf, {2, 6}, "cmd_after", .BrightYellow)
	munin.print_at(buf, {20, 6}, fmt.tprintf("pipeline: %s", label), color)

	for line, i in model.log {
		munin.print_at(buf, {22, 7 + i}, line, .BrightBlack)
	}

	// The self-clearing toast
	if len(model.toast) > 0 {
		munin.print_at(buf, {2, 17}, fmt.tprintf("  %s  ", model.toast), .BrightGreen)
	}

	munin.print_at(
		buf,
		{2, 19},
		"SPACE: run pipeline   P: pause/resume clock   Q: quit",
		.BrightBlue,
	)
}

// ============================================================
// INPUT
// ============================================================

input_handler :: proc() -> Maybe(Msg) {
	if event, ok := munin.read_key().?; ok {
		if event.key == .Char {
			switch event.char {
			case ' ':
				return Start_Pipeline{}
			case 'p', 'P':
				return Toggle_Clock{}
			case 'q', 'Q':
				return Quit{}
			case 'c':
				if event.ctrl {
					return Quit{}
				}
			}
		}
	}
	return nil
}

main :: proc() {
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
	defer destroy_model(&program.model)

	// Start the clock before the loop runs. Commands can be scheduled from
	// anywhere that can reach the program, not only from update.
	program.model.clock = munin.cmd_every(&program.cmds, time.Second, Msg(Tick{}))

	munin.run(&program, input_handler)
}
