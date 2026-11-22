extends GutTest

var box: IOCContainer
var scan_errors: PackedStringArray = PackedStringArray()


func before_each() -> void:
	_ensure_action("move_left")
	_ensure_action("move_right")
	_ensure_action("fire")
	_ensure_action("aim")
	_release_all()
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	scan_errors = PackedStringArray()
	for err in get_errors():
		if err.handled:
			continue
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("InputAction") != -1 or text.find("Action") != -1 or text.find("action") != -1:
			scan_errors.append(text)
		err.handled = true


func after_each() -> void:
	get_tree().paused = false
	_release_all()
	if box != null:
		box.shutdown()
	box = null


func test_axis_strength_and_pressed_are_polled_before_process() -> void:
	var pad := box.resolve(ActionPad) as ActionPad
	Input.action_press("move_right")
	Input.action_press("fire")
	Input.action_press("aim")
	var driver := get_tree().root.get_node("IocFrameDriver") as FrameDriver
	driver._process(0.1)
	assert_eq(pad.axis, 1.0, "the positive action is one")
	assert_eq(pad.strength, 1.0, "a held action has full strength")
	assert_true(pad.down, "a held action is pressed")
	assert_eq(pad.order, ["steer", "fire", "aim", "tick"], "actions run before process")
	Input.action_release("move_right")
	Input.action_press("move_left")
	Input.action_press("move_right")
	box.run_input_actions()
	assert_eq(pad.axis, 0.0, "both sides cancel")
	_release_all()
	box.run_input_actions()
	assert_eq(pad.axis, 0.0, "a released axis is zero")
	assert_eq(pad.strength, 0.0, "a released action has no strength")
	assert_false(pad.down, "a released action is not pressed")


func test_negative_axis_is_minus_one() -> void:
	var pad := box.resolve(ActionPad) as ActionPad
	Input.action_press("move_left")
	box.run_input_actions()
	assert_eq(pad.axis, -1.0, "the first action is the negative side")


func test_scene_action_leaves_with_the_scene() -> void:
	var packed := load("res://test/ioc/async_room.tscn") as PackedScene
	var room := packed.instantiate()
	add_child(room)
	_handle_scene_noise()
	var scene_action := box.resolve(SceneAction, [], room) as SceneAction
	Input.action_press("aim")
	box.run_input_actions()
	assert_eq(scene_action.seen, [true], "the scene product is polled")
	room.free()
	_handle_scene_noise()
	box.run_input_actions()
	assert_eq(scene_action.seen, [true], "the scene product stops when the root leaves")


func test_paused_tree_does_not_poll() -> void:
	var pad := box.resolve(ActionPad) as ActionPad
	Input.action_press("aim")
	get_tree().paused = true
	await get_tree().process_frame
	assert_eq(pad.order.size(), 0, "a paused tree skips the frame node")
	get_tree().paused = false
	await get_tree().process_frame
	assert_gt(pad.order.size(), 0, "polling resumes when the tree is unpaused")


func test_advice_wraps_a_polled_action() -> void:
	var log := box.resolve(CallLog) as CallLog
	var woven := box.resolve(ActionWoven) as ActionWoven
	Input.action_press("aim")
	box.run_input_actions()
	assert_eq(woven.ran, 1, "the method ran")
	assert_eq(log.calls[0], "before:aim:[true]", "advice sees the held state")
	assert_eq(log.calls[2], "after:aim:<null>", "after sees the return")


func test_a_polled_action_that_awaits_is_rejected() -> void:
	var waiting := box.resolve(ActionAwait) as ActionAwait
	box.run_input_actions()
	assert_eq(waiting.started, 1, "the method started")
	assert_engine_error("ActionAwait.aim cannot await")
	waiting.resume.emit()


func test_bad_marks_are_rejected() -> void:
	assert_eq(_scan_count("@InputAction on ActionBadShape belongs on a method"), 2, "the class mark and the field mark are rejected")
	assert_true(_scan_has("ActionBadShape.no_args must take one float or bool"), "a method needs the held value")
	assert_true(_scan_has("ActionBadShape.two must take one float or bool"), "an extra argument is rejected")
	assert_true(_scan_has("ActionBadShape.stat is static and cannot poll an action"), "a static method is rejected")
	assert_true(_scan_has("ActionBadShape.untyped must take one float or bool"), "an untyped argument is rejected")
	assert_true(_scan_has("ActionBadShape.empty needs an action"), "an empty mark needs an action")
	assert_true(_scan_has("action \"no_such_ioc_action\" is not in the input map"), "a missing action is rejected")
	assert_true(_scan_has("ActionBadShape.axis_bool axis needs a float"), "two actions need a float")
	assert_true(_scan_has("ActionNode.aim is @InputAction on a Node"), "a node keeps its own process")
	assert_true(_scan_has("ActionConfig.aim is @InputAction on a configuration"), "a configuration method is rejected")
	assert_true(_scan_has("@InputAction on ActionConfig belongs on a method"), "a configuration class mark is rejected")


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _release_all() -> void:
	for action in ["move_left", "move_right", "fire", "aim"]:
		if InputMap.has_action(action):
			Input.action_release(action)


func _scan_has(text: String) -> bool:
	return _scan_count(text) > 0


func _scan_count(text: String) -> int:
	var count := 0
	for line in scan_errors:
		if line.find(text) != -1:
			count += 1
	return count


func _handle_scene_noise() -> void:
	for err in get_errors():
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("NoSuchAddon") != -1 or text.find("not a global class") != -1:
			err.handled = true
