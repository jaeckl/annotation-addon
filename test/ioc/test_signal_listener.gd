extends GutTest

var box: IOCContainer
var scan_errors: PackedStringArray = PackedStringArray()


func before_each() -> void:
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	scan_errors = PackedStringArray()
	for err in get_errors():
		if err.handled:
			continue
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("Signal") != -1:
			scan_errors.append(text)
		err.handled = true


func after_each() -> void:
	if box != null:
		box.shutdown()
	box = null
	for child in get_tree().root.get_children():
		if child is SignalBell or child is SignalPad or child is SignalArea or child is SignalRepeat or child is SignalWoven or child is SignalAwait or child is SignalOdd or child is SignalMissingPath or child is SceneSignal:
			child.free()


func test_a_component_signal_calls_its_method() -> void:
	var bell := box.resolve(SignalBell) as SignalBell
	await get_tree().process_frame
	bell.rang.emit(3)
	assert_eq(bell.seen, [3], "the component method receives the signal argument")
	box.shutdown()
	bell.rang.emit(9)
	assert_eq(bell.seen, [3], "shutdown drops the connection")
	box = null


func test_a_child_path_publishes_an_event() -> void:
	var pad := box.resolve(SignalPad) as SignalPad
	var desk := box.resolve(TouchDesk) as TouchDesk
	await get_tree().process_frame
	var body := Node2D.new()
	pad.get_node("Hitbox").touched.emit(body)
	assert_eq(pad.seen, [body], "the path resolves to the child added in _ready")
	assert_eq(desk.seen, [body], "an Event return is published")
	body.free()


func test_a_native_signal_accepts_a_parent_argument() -> void:
	var area := box.resolve(SignalArea) as SignalArea
	await get_tree().process_frame
	var body := Node2D.new()
	area.body_entered.emit(body)
	assert_eq(area.seen, [body], "a Node parameter accepts the Node2D argument")
	body.free()


func test_repeatable_marks_connect_each_signal() -> void:
	var repeat := box.resolve(SignalRepeat) as SignalRepeat
	await get_tree().process_frame
	repeat.ping.emit()
	repeat.pong.emit()
	assert_eq(repeat.seen, [0, 1], "each mark connects the method")


func test_scene_signal_leaves_with_the_scene() -> void:
	var packed := load("res://test/ioc/async_room.tscn") as PackedScene
	var room := packed.instantiate()
	add_child(room)
	_handle_scene_noise()
	var bell := box.resolve(SceneSignal, [], room) as SceneSignal
	await get_tree().process_frame
	bell.rang.emit()
	assert_eq(bell.seen, 1, "the scene component hears its signal")
	room.free()
	assert_false(is_instance_valid(bell), "the scene component leaves with the root")


func test_advice_wraps_the_slot() -> void:
	var log := box.resolve(CallLog) as CallLog
	var woven := box.resolve(SignalWoven) as SignalWoven
	await get_tree().process_frame
	woven.rang.emit(4)
	assert_eq(log.calls[0], "before:on_rang:[4]", "advice sees the signal argument")
	assert_eq(log.calls[1], "around:on_rang", "around wraps the slot")
	assert_eq(log.calls[2], "after:on_rang:<null>", "after sees the return")


func test_a_missing_path_is_rejected() -> void:
	box.resolve(SignalMissingPath)
	await get_tree().process_frame
	assert_engine_error('SignalMissingPath.touched path "Nope" is missing')


func test_an_odd_return_is_rejected() -> void:
	var odd := box.resolve(SignalOdd) as SignalOdd
	await get_tree().process_frame
	odd.rang.emit()
	assert_engine_error("SignalOdd.on_rang returned int, not an Event.")


func test_a_slot_that_awaits_is_rejected() -> void:
	var waiting := box.resolve(SignalAwait) as SignalAwait
	await get_tree().process_frame
	waiting.rang.emit()
	assert_engine_error("SignalAwait.on_rang cannot await")


func test_bad_marks_are_rejected() -> void:
	assert_eq(_scan_count("@SignalListener on SignalBadShape belongs on a method"), 2, "the class mark and the field mark are rejected")
	assert_true(_scan_has("SignalBadShape.bare needs a signal"), "a method needs a signal name")
	assert_true(_scan_has('SignalBadShape.on_nope signal "nope" is missing'), "a missing signal is rejected")
	assert_true(_scan_has('SignalBadShape.on_rang must match signal "rang"'), "the argument list must match")
	assert_true(_scan_has("SignalBadShape.stat is static and cannot listen to a signal"), "a static method is rejected")
	assert_true(_scan_has("SignalBadShape.numbered must return an Event or nothing"), "a non-event return is rejected")
	assert_true(_scan_has("SignalPlain.on_rang is @SignalListener on a RefCounted"), "a RefCounted product is rejected")
	assert_true(_scan_has("SignalLoose.on_rang is @SignalListener and SignalLoose is not a Node component"), "a scene node is not a component")
	assert_true(_scan_has("SignalConfig.on_rang is @SignalListener on a configuration"), "a configuration method is rejected")
	assert_true(_scan_has("@SignalListener on SignalConfig belongs on a method"), "a configuration class mark is rejected")


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
