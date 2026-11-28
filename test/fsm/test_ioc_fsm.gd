extends GutTest

var box: IOCContainer


func before_each() -> void:
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	for err in get_errors():
		err.handled = true


func after_each() -> void:
	if box != null:
		box.shutdown()
	box = null


func test_process_drives_tick_on_an_fsm_object() -> void:
	var flow := box.resolve(FsmFlow) as FsmFlow
	assert_not_null(flow, "FsmFlow resolves")
	assert_eq(flow.state, FsmFlow.Phase.MENU, "starts in MENU")
	box.run_process(0.5)
	assert_eq(flow.ticks, [["menu", 0.5]], "@Process calls tick for the current while")
	assert_true(flow.try_goto(FsmFlow.Phase.PLAY), "map allows MENU to PLAY")
	assert_eq(flow.enters, ["play"], "enter ran")
	box.run_process(0.25)
	assert_eq(flow.ticks, [["menu", 0.5], ["play", 0.25]], "play while runs after transition")


func test_hook_rejects_fsm_marks_on_a_plain_product() -> void:
	# Discovery may or may not load FsmBadPlain as a component — it has no @Component.
	# Build a one-off instance through the hook path by resolving a fake: call the hook.
	var hook := box.resolve(FsmHook) as FsmHook
	assert_not_null(hook, "FsmHook is published")
	var plain := FsmBadPlain.new()
	hook.before_ready(plain)
	assert_push_error("FsmBadPlain has FSM marks and does not extend Fsm or FsmObject")
