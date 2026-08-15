package munin

import "core:time"

// ============================================================
// COMMANDS
// ============================================================
//
// The Elm Architecture has three parts; munin shipped two. Without a way to
// say "and then do this", an application cannot start a timer, schedule a
// message, or quit from anywhere except by threading a bool back through
// update - so timing state ends up in file-scope globals and repeating work
// gets polled from a subscription that runs every frame.
//
// A Cmd_Context is the missing third part. It is handed to update, which can
// post messages back to itself, schedule them for later, repeat them on an
// interval, or ask the program to stop:
//
//	update :: proc(msg: Msg, model: Model, cmds: ^munin.Cmd_Context(Msg)) -> Model {
//		switch m in msg {
//		case Start:
//			munin.cmd_every(cmds, 500 * time.Millisecond, Blink{})
//		case Blink:
//			model.cursor_on = !model.cursor_on
//		case Quit:
//			munin.cmd_quit(cmds)
//		}
//		return model
//	}
//
// Programs built with the original update signature are unaffected: they
// simply never receive a context.

@(private)
Timer :: struct($Msg: typeid) {
	due:      time.Time,
	interval: time.Duration, // 0 for a one-shot
	msg:      Msg,
	cancelled: bool,
	id:        int,
}

// Handle to a scheduled message, so it can be cancelled.
Cmd_Handle :: distinct int

Cmd_Context :: struct($Msg: typeid) {
	queue:   [dynamic]Msg,
	timers:  [dynamic]Timer(Msg),
	quit:    bool,
	next_id: int,
}

// Deliver `msg` to update on the next iteration.
//
// Use this to chain work without recursing through update, and to turn one
// event into several.
cmd_send :: proc(cmds: ^Cmd_Context($Msg), msg: Msg) {
	append(&cmds.queue, msg)
}

// Deliver `msg` once, after `delay`.
cmd_after :: proc(cmds: ^Cmd_Context($Msg), delay: time.Duration, msg: Msg) -> Cmd_Handle {
	cmds.next_id += 1
	append(
		&cmds.timers,
		Timer(Msg) {
			due = time.time_add(time.now(), delay),
			interval = 0,
			msg = msg,
			id = cmds.next_id,
		},
	)
	return Cmd_Handle(cmds.next_id)
}

// Deliver `msg` every `interval` until cancelled.
//
// This replaces polling from a subscription: the run loop knows when the next
// one is due, rather than the application checking a clock on every frame.
cmd_every :: proc(cmds: ^Cmd_Context($Msg), interval: time.Duration, msg: Msg) -> Cmd_Handle {
	cmds.next_id += 1
	append(
		&cmds.timers,
		Timer(Msg) {
			due = time.time_add(time.now(), interval),
			interval = max(interval, time.Millisecond),
			msg = msg,
			id = cmds.next_id,
		},
	)
	return Cmd_Handle(cmds.next_id)
}

// Cancel a scheduled or repeating message.
cmd_cancel :: proc(cmds: ^Cmd_Context($Msg), handle: Cmd_Handle) {
	for &timer in cmds.timers {
		if timer.id == int(handle) {
			timer.cancelled = true
		}
	}
}

// Ask the program to stop after the current iteration.
cmd_quit :: proc(cmds: ^Cmd_Context($Msg)) {
	cmds.quit = true
}

// Drop every pending message and timer.
cmd_clear :: proc(cmds: ^Cmd_Context($Msg)) {
	clear(&cmds.queue)
	clear(&cmds.timers)
}

@(private)
cmd_destroy :: proc(cmds: ^Cmd_Context($Msg)) {
	delete(cmds.queue)
	delete(cmds.timers)
	cmds.queue = nil
	cmds.timers = nil
}

// Collect the timers that are due, rescheduling repeating ones and dropping
// the rest. Returns how many messages were appended to `out`.
@(private)
cmd_collect_due :: proc(cmds: ^Cmd_Context($Msg), now: time.Time, out: ^[dynamic]Msg) -> int {
	fired := 0

	live := 0
	for i in 0 ..< len(cmds.timers) {
		timer := cmds.timers[i]

		if timer.cancelled {
			continue
		}

		if time.diff(timer.due, now) >= 0 {
			append(out, timer.msg)
			fired += 1

			if timer.interval <= 0 {
				continue // one-shot: done
			}
			timer.due = time.time_add(now, timer.interval)
		}

		cmds.timers[live] = timer
		live += 1
	}
	resize(&cmds.timers, live)

	return fired
}

// How long until the next timer is due, or -1 when nothing is scheduled.
// The run loop uses this so a program with a slow timer still sleeps.
@(private)
cmd_next_due :: proc(cmds: ^Cmd_Context($Msg), now: time.Time) -> time.Duration {
	soonest := time.Duration(-1)
	for timer in cmds.timers {
		if timer.cancelled {
			continue
		}
		remaining := time.diff(now, timer.due)
		if remaining < 0 {
			remaining = 0
		}
		if soonest < 0 || remaining < soonest {
			soonest = remaining
		}
	}
	return soonest
}
