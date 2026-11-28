extends GutTest


func _brain() -> FsmBrain:
	var brain := FsmBrain.new()
	add_child(brain)
	return brain


func after_each() -> void:
	for child in get_children():
		child.free()


func test_tick_runs_only_the_current_while() -> void:
	var brain := _brain()
	brain.tick(0.1)
	assert_eq(brain.ticks, [["idle", 0.1]], "idle runs while IDLE")
	brain.goto(FsmBrain.Phase.RUN)
	brain.tick(0.2)
	assert_eq(brain.ticks, [["idle", 0.1], ["run", 0.2]], "run runs after goto")


func test_same_state_goto_is_a_noop() -> void:
	var brain := _brain()
	brain.goto(FsmBrain.Phase.ATTACK)
	assert_eq(brain.enters, ["attack"], "enter runs once")
	brain.goto(FsmBrain.Phase.ATTACK)
	assert_eq(brain.enters, ["attack"], "same-state goto does not re-enter")
	assert_eq(brain.exits, [], "same-state goto does not exit")


func test_goto_runs_exit_then_enter() -> void:
	var brain := _brain()
	brain.goto(FsmBrain.Phase.ATTACK)
	brain.goto(FsmBrain.Phase.IDLE)
	assert_eq(brain.exits, ["attack"], "exit runs when leaving")
	assert_eq(brain.state, FsmBrain.Phase.IDLE, "state updates")


func test_try_goto_respects_the_transition_map() -> void:
	var brain := _brain()
	assert_true(brain.try_goto(FsmBrain.Phase.RUN), "IDLE may go to RUN")
	assert_eq(brain.state, FsmBrain.Phase.RUN, "state is RUN")
	assert_true(brain.try_goto(FsmBrain.Phase.IDLE), "RUN may go to IDLE")
	brain.goto(FsmBrain.Phase.ATTACK)
	assert_false(brain.try_goto(FsmBrain.Phase.RUN), "ATTACK may not go to RUN")
	assert_push_error("FsmBrain cannot try_goto from")
	assert_eq(brain.state, FsmBrain.Phase.ATTACK, "rejected try_goto keeps state")


func test_goto_ignores_the_transition_map() -> void:
	var brain := _brain()
	brain.goto(FsmBrain.Phase.ATTACK)
	brain.goto(FsmBrain.Phase.RUN)
	assert_eq(brain.state, FsmBrain.Phase.RUN, "force goto skips the map")


func test_open_try_goto_without_a_map() -> void:
	var open := FsmOpen.new()
	add_child(open)
	assert_true(open.try_goto(FsmOpen.Phase.C), "no map means any edge")
	assert_eq(open.state, FsmOpen.Phase.C, "state moved")
