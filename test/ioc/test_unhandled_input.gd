extends GutTest

var box: IOCContainer
var scan_errors: PackedStringArray = PackedStringArray()


func before_each() -> void:
	_ensure_action("jump", KEY_SPACE)
	_ensure_action("attack", KEY_F)
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	scan_errors = PackedStringArray()
	for err in get_errors():
		if err.handled:
			continue
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("UnhandledInput") != -1 or text.find("action") != -1 or text.find("Input") != -1:
			scan_errors.append(text)
		err.handled = true


func after_each() -> void:
	get_tree().paused = false
	if box != null:
		box.shutdown()
	box = null


func test_filters_keep_motion_away_from_an_action() -> void:
	var pad := box.resolve(InputPad) as InputPad
	box.run_unhandled_input(_motion())
	assert_eq(pad.log, ["any"], "motion reaches only the open method")
	pad.log.clear()
	box.run_unhandled_input(_key(KEY_SPACE, true, false))
	assert_eq(pad.log, ["any", "key", "jump:true", "pressed"], "a jump press reaches the press filter")
	pad.log.clear()
	box.run_unhandled_input(_key(KEY_SPACE, false, false))
	assert_eq(pad.log, ["any", "key", "jump:false", "released"], "a jump release reaches the release filter")
	pad.log.clear()
	box.run_unhandled_input(_key(KEY_SPACE, true, true))
	assert_eq(pad.log, ["any", "key", "jump:true"], "echo is not a press")


func test_repeatable_actions_share_one_method() -> void:
	var both := box.resolve(InputBoth) as InputBoth
	box.run_unhandled_input(_key(KEY_SPACE, true, false))
	box.run_unhandled_input(_key(KEY_F, true, false))
	box.run_unhandled_input(_key(KEY_F, false, false))
	assert_eq(both.log, ["hit", "hit"], "jump and an attack press call the method")


func test_true_stops_later_methods_and_marks_the_event() -> void:
	var gate := box.resolve(InputGate) as InputGate
	var after := box.resolve(InputAfter) as InputAfter
	var driver := get_tree().root.get_node("IocUnhandledInput") as UnhandledInputDriver
	assert_true(driver.is_processing_unhandled_input(), "the node listens for unhandled input")
	driver._unhandled_input(_key(KEY_SPACE, true, false))
	assert_eq(gate.ran, 1, "the first method ran")
	assert_eq(after.ran, 0, "a later method does not run")
	assert_true(get_viewport().is_input_handled(), "the driver marks the event handled")


func test_scene_input_leaves_with_the_scene() -> void:
	var packed := load("res://test/ioc/async_room.tscn") as PackedScene
	var room := packed.instantiate()
	add_child(room)
	_handle_scene_noise()
	var scene_input := box.resolve(SceneInput, [], room) as SceneInput
	var pad := box.resolve(InputPad) as InputPad
	box.run_unhandled_input(_motion())
	assert_eq(scene_input.ran, 1, "the scene product hears the event")
	assert_eq(pad.log, ["any"], "the app product hears it too")
	room.free()
	_handle_scene_noise()
	box.run_unhandled_input(_motion())
	assert_eq(scene_input.ran, 1, "the scene product stops when the root leaves")
	assert_eq(pad.log, ["any", "any"], "the app product keeps hearing events")


func test_paused_tree_skips_the_driver() -> void:
	var pad := box.resolve(InputPad) as InputPad
	get_tree().paused = true
	get_viewport().push_input(_key(KEY_F13, true, false))
	assert_eq(pad.log.size(), 0, "a paused tree skips the input node")
	get_tree().paused = false
	get_viewport().push_input(_key(KEY_F13, true, false))
	assert_eq(pad.log, ["any", "key"], "input resumes when the tree is unpaused")


func test_advice_wraps_unhandled_input() -> void:
	var log := box.resolve(CallLog) as CallLog
	var woven := box.resolve(InputWoven) as InputWoven
	var event := _motion()
	box.run_unhandled_input(event)
	assert_eq(woven.ran, 1, "the method ran")
	assert_eq(log.calls[0], "before:on_input:[%s]" % event, "advice sees the event")
	assert_eq(log.calls[2], "after:on_input:<null>", "after sees the return")


func test_a_handler_that_awaits_or_returns_an_int_is_rejected() -> void:
	var waiting := box.resolve(InputAwait) as InputAwait
	box.run_unhandled_input(_motion())
	assert_eq(waiting.started, 1, "the method started")
	assert_engine_error("InputAwait.on_input cannot await")
	waiting.resume.emit()
	box.resolve(InputOdd)
	box.run_unhandled_input(_motion())
	assert_engine_error("InputAwait.on_input cannot await")
	assert_engine_error("InputOdd.on_input must return bool or nothing")


func test_bad_marks_are_rejected() -> void:
	assert_eq(_scan_count("@UnhandledInput on InputBadShape belongs on a method"), 2, "the class mark and the field mark are rejected")
	assert_true(_scan_has("InputBadShape.no_args must take one InputEvent"), "a method needs the event")
	assert_true(_scan_has("InputBadShape.two must take one InputEvent"), "an extra argument is rejected")
	assert_true(_scan_has("InputBadShape.stat is static and cannot take input"), "a static method is rejected")
	assert_true(_scan_has("InputBadShape.untyped must take one InputEvent"), "an untyped argument is rejected")
	assert_true(_scan_has("action \"no_such_ioc_action\" is not in the input map"), "a missing action is rejected")
	assert_true(_scan_has("InputBadShape.both cannot be both pressed and released"), "the two states cannot combine")
	assert_true(_scan_has("InputBadShape.bare_pressed needs an action"), "pressed needs an action")
	assert_true(_scan_has("InputNode.on_input is @UnhandledInput on a Node"), "a node keeps _unhandled_input")
	assert_true(_scan_has("InputConfig.on_input is @UnhandledInput on a configuration"), "a configuration method is rejected")
	assert_true(_scan_has("@UnhandledInput on InputConfig belongs on a method"), "a configuration class mark is rejected")


func _ensure_action(action: String, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var key := InputEventKey.new()
	key.keycode = keycode
	InputMap.action_add_event(action, key)


func _key(keycode: Key, pressed: bool, echo: bool) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = pressed
	key.echo = echo
	return key


func _motion() -> InputEventMouseMotion:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(1, 2)
	return motion


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
