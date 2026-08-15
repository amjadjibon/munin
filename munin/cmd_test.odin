package munin

import "core:strings"
import "core:testing"
import "core:time"

// ============================================================
// COMMANDS
// ============================================================

@(private = "file")
Test_Msg :: enum {
	Tick,
	Blink,
	Done,
}

@(private = "file")
drain_due :: proc(cmds: ^Cmd_Context(Test_Msg), at: time.Time) -> [dynamic]Test_Msg {
	out := make([dynamic]Test_Msg, context.temp_allocator)
	cmd_collect_due(cmds, at, &out)
	return out
}

@(test)
test_cmd_send_queues_a_message :: proc(t: ^testing.T) {
	cmds: Cmd_Context(Test_Msg)
	defer cmd_destroy(&cmds)

	cmd_send(&cmds, Test_Msg.Tick)
	cmd_send(&cmds, Test_Msg.Done)

	testing.expect_value(t, len(cmds.queue), 2)
	testing.expect_value(t, cmds.queue[0], Test_Msg.Tick)
	testing.expect_value(t, cmds.queue[1], Test_Msg.Done)
}

@(test)
test_cmd_quit_is_recorded :: proc(t: ^testing.T) {
	cmds: Cmd_Context(Test_Msg)
	defer cmd_destroy(&cmds)

	testing.expect(t, !cmds.quit, "not quitting by default")
	cmd_quit(&cmds)
	testing.expect(t, cmds.quit, "quit should be recorded")
}

@(test)
test_cmd_after_fires_once_when_due :: proc(t: ^testing.T) {
	cmds: Cmd_Context(Test_Msg)
	defer cmd_destroy(&cmds)

	now := time.now()
	cmd_after(&cmds, 50 * time.Millisecond, Test_Msg.Done)

	// Not yet.
	early := drain_due(&cmds, now)
	testing.expect_value(t, len(early), 0)

	// Due. Times are taken from the timer itself rather than from a clock
	// read before it was scheduled, which is a race.
	due := cmds.timers[0].due
	fired := drain_due(&cmds, time.time_add(due, time.Millisecond))
	testing.expect_value(t, len(fired), 1)
	testing.expect_value(t, fired[0], Test_Msg.Done)

	// One-shot: gone afterwards.
	again := drain_due(&cmds, time.time_add(now, time.Second))
	testing.expect_value(t, len(again), 0)
	testing.expect_value(t, len(cmds.timers), 0)
	free_all(context.temp_allocator)
}

@(test)
test_cmd_every_reschedules :: proc(t: ^testing.T) {
	cmds: Cmd_Context(Test_Msg)
	defer cmd_destroy(&cmds)

	cmd_every(&cmds, 100 * time.Millisecond, Test_Msg.Blink)

	for i in 1 ..= 3 {
		// Fire relative to when this timer is actually due, so the test does
		// not depend on how long scheduling took.
		at := time.time_add(cmds.timers[0].due, time.Millisecond)
		fired := drain_due(&cmds, at)
		testing.expectf(t, len(fired) == 1, "tick %d should fire once, fired %d", i, len(fired))
		if len(fired) > 0 {
			testing.expect_value(t, fired[0], Test_Msg.Blink)
		}
	}

	testing.expect_value(t, len(cmds.timers), 1) // still scheduled
	free_all(context.temp_allocator)
}

@(test)
test_cmd_cancel_stops_a_repeating_message :: proc(t: ^testing.T) {
	cmds: Cmd_Context(Test_Msg)
	defer cmd_destroy(&cmds)

	handle := cmd_every(&cmds, 10 * time.Millisecond, Test_Msg.Blink)
	cmd_cancel(&cmds, handle)

	fired := drain_due(&cmds, time.time_add(time.now(), time.Second))
	testing.expect_value(t, len(fired), 0)
	testing.expect_value(t, len(cmds.timers), 0)
	free_all(context.temp_allocator)
}

@(test)
test_cmd_cancel_leaves_other_timers_alone :: proc(t: ^testing.T) {
	cmds: Cmd_Context(Test_Msg)
	defer cmd_destroy(&cmds)

	keep := cmd_every(&cmds, 10 * time.Millisecond, Test_Msg.Tick)
	drop := cmd_every(&cmds, 10 * time.Millisecond, Test_Msg.Blink)
	cmd_cancel(&cmds, drop)
	_ = keep

	fired := drain_due(&cmds, time.time_add(time.now(), time.Second))
	testing.expect_value(t, len(fired), 1)
	testing.expect_value(t, fired[0], Test_Msg.Tick)
	free_all(context.temp_allocator)
}

@(test)
test_cmd_multiple_timers_fire_together :: proc(t: ^testing.T) {
	cmds: Cmd_Context(Test_Msg)
	defer cmd_destroy(&cmds)

	cmd_after(&cmds, 10 * time.Millisecond, Test_Msg.Tick)
	cmd_after(&cmds, 20 * time.Millisecond, Test_Msg.Blink)
	cmd_after(&cmds, time.Hour, Test_Msg.Done)

	// Past the second timer, nowhere near the third.
	fired := drain_due(&cmds, time.time_add(cmds.timers[1].due, time.Millisecond))
	testing.expect_value(t, len(fired), 2)
	testing.expect_value(t, len(cmds.timers), 1) // the far-future one survives
	free_all(context.temp_allocator)
}

@(test)
test_cmd_next_due_reports_the_soonest_timer :: proc(t: ^testing.T) {
	cmds: Cmd_Context(Test_Msg)
	defer cmd_destroy(&cmds)

	now := time.now()
	testing.expect(t, cmd_next_due(&cmds, now) < 0, "nothing scheduled")

	cmd_after(&cmds, time.Second, Test_Msg.Done)
	cmd_after(&cmds, 100 * time.Millisecond, Test_Msg.Tick)

	// The timers were scheduled a moment after `now`, so allow for that when
	// checking that the 100ms one - not the 1s one - is what gets reported.
	due := cmd_next_due(&cmds, now)
	testing.expect(t, due >= 0, "a timer is scheduled")
	testing.expectf(
		t,
		due <= 150 * time.Millisecond,
		"should report the soonest timer, reported %v",
		due,
	)
}

@(test)
test_cmd_next_due_is_zero_when_overdue :: proc(t: ^testing.T) {
	cmds: Cmd_Context(Test_Msg)
	defer cmd_destroy(&cmds)

	cmd_after(&cmds, 10 * time.Millisecond, Test_Msg.Tick)

	due := cmd_next_due(&cmds, time.time_add(time.now(), time.Second))
	testing.expect_value(t, due, time.Duration(0))
}

@(test)
test_cmd_clear_drops_everything :: proc(t: ^testing.T) {
	cmds: Cmd_Context(Test_Msg)
	defer cmd_destroy(&cmds)

	cmd_send(&cmds, Test_Msg.Tick)
	cmd_every(&cmds, time.Millisecond, Test_Msg.Blink)
	cmd_clear(&cmds)

	testing.expect_value(t, len(cmds.queue), 0)
	testing.expect_value(t, len(cmds.timers), 0)
}

// ============================================================
// PROGRAM WIRING
// ============================================================

@(private = "file")
Cmd_Model :: struct {
	ticks: int,
}

@(private = "file")
cmd_init :: proc() -> Cmd_Model {
	return Cmd_Model{}
}

@(private = "file")
cmd_update :: proc(
	msg: Test_Msg,
	model: Cmd_Model,
	cmds: ^Cmd_Context(Test_Msg),
) -> Cmd_Model {
	m := model
	switch msg {
	case .Tick:
		m.ticks += 1
		if m.ticks >= 3 {
			cmd_send(cmds, Test_Msg.Done)
		}
	case .Blink:
	case .Done:
		cmd_quit(cmds)
	}
	return m
}

@(private = "file")
cmd_view :: proc(model: Cmd_Model, buf: ^strings.Builder) {
}

@(test)
test_make_program_with_cmds_selects_the_command_update :: proc(t: ^testing.T) {
	program := make_program(cmd_init, cmd_update, cmd_view)
	defer destroy_program(&program)

	testing.expect(t, program.update_cmd != nil, "the command update should be installed")
	testing.expect(t, program.update == nil, "the plain update should be unset")
}

@(test)
test_command_update_drives_the_model_and_quits :: proc(t: ^testing.T) {
	// Mirrors what the run loop does: dispatch, then drain what update posted.
	program := make_program(cmd_init, cmd_update, cmd_view)
	defer destroy_program(&program)

	for _ in 0 ..< 3 {
		program.model = program.update_cmd(.Tick, program.model, &program.cmds)
	}
	testing.expect_value(t, program.model.ticks, 3)
	testing.expect_value(t, len(program.cmds.queue), 1)

	program.model = program.update_cmd(program.cmds.queue[0], program.model, &program.cmds)
	testing.expect(t, program.cmds.quit, "Done should have asked the program to stop")
}
