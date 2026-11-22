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
		if text.find("Process") != -1 or text.find("tick") != -1 or text.find("Frame") != -1:
			scan_errors.append(text)
		err.handled = true


func after_each() -> void:
	get_tree().paused = false
	if box != null:
		box.shutdown()
	box = null


func test_process_and_physics_use_separate_clocks() -> void:
	var clock := box.resolve(FrameClock) as FrameClock
	box.run_process(0.5)
	assert_eq(clock.idle, [0.5], "the idle method receives the delta")
	assert_eq(clock.physics.size(), 0, "the physics method waits for its clock")
	box.run_physics_process(0.016)
	assert_eq(clock.physics, [0.016], "the physics method receives its delta")
	assert_eq(clock.idle, [0.5], "the idle method is not called again")


func test_methods_run_in_source_order_then_registration_order() -> void:
	var order := box.resolve(FrameOrder) as FrameOrder
	var log := box.resolve(FrameLog) as FrameLog
	box.resolve(FrameEarly)
	box.resolve(FrameLate)
	box.run_process(0.1)
	assert_eq(order.log, ["first", "second"], "methods on one product run in source order")
	assert_eq(log.lines, ["early", "late"], "products run in the order they were published")


func test_the_frame_node_calls_process_and_physics() -> void:
	var clock := box.resolve(FrameClock) as FrameClock
	var driver := get_tree().root.get_node("IocFrameDriver")
	assert_true(driver is FrameDriver, "the container parents the frame node")
	assert_eq(driver.process_mode, Node.PROCESS_MODE_INHERIT, "the frame node pauses with the tree")
	await get_tree().process_frame
	assert_gt(clock.idle.size(), 0, "an idle frame calls the method")
	await get_tree().physics_frame
	assert_gt(clock.physics.size(), 0, "a physics frame calls the method")


func test_paused_tree_does_not_tick() -> void:
	var clock := box.resolve(FrameClock) as FrameClock
	get_tree().paused = true
	await get_tree().process_frame
	assert_eq(clock.idle.size(), 0, "a paused tree skips the frame node")
	get_tree().paused = false
	await get_tree().process_frame
	assert_gt(clock.idle.size(), 0, "the tick resumes when the tree is unpaused")


func test_scene_tick_leaves_with_the_scene() -> void:
	var packed := load("res://test/ioc/async_room.tscn") as PackedScene
	var room := packed.instantiate()
	add_child(room)
	_handle_scene_noise()
	var tick := box.resolve(SceneTick, [], room) as SceneTick
	var clock := box.resolve(FrameClock) as FrameClock
	box.run_process(0.25)
	assert_eq(tick.seen, [0.25], "the scene product ticks while the root is open")
	assert_eq(clock.idle, [0.25], "an app product ticks in the same pass")
	room.free()
	_handle_scene_noise()
	box.run_process(0.5)
	assert_eq(tick.seen, [0.25], "the scene product stops when the root leaves")
	assert_eq(clock.idle, [0.25, 0.5], "the app product keeps ticking")


func test_factory_product_ticks() -> void:
	var made := box.resolve(FrameMade) as FrameMade
	box.run_process(0.1)
	assert_eq(made.ticks, 1, "a factory product is called after it is published")


func test_advice_wraps_a_ticked_method() -> void:
	var log := box.resolve(CallLog) as CallLog
	var woven := box.resolve(FrameWoven) as FrameWoven
	box.run_process(0.2)
	assert_eq(woven.ran, 1, "the method ran")
	assert_eq(log.calls[0], "before:tick:[0.2]", "advice sees the delta")
	assert_eq(log.calls[1], "around:tick", "around wraps the tick")
	assert_eq(log.calls[2], "after:tick:<null>", "after sees the return")


func test_a_tick_that_awaits_is_rejected() -> void:
	var waiting := box.resolve(FrameAwait) as FrameAwait
	box.run_process(0.1)
	assert_eq(waiting.started, 1, "the method started")
	assert_engine_error("FrameAwait.tick cannot await")
	waiting.resume.emit()


func test_bad_marks_are_rejected_and_not_called() -> void:
	assert_eq(_scan_count("@Process on FrameBadShape belongs on a method"), 2, "the class mark and the field mark are rejected")
	assert_true(_scan_has("FrameBadShape.no_args must take one float"), "a method needs the delta")
	assert_true(_scan_has("FrameBadShape.two must take one float"), "an extra argument is rejected")
	assert_true(_scan_has("FrameBadShape.stat is static and cannot tick"), "a static method is rejected")
	assert_true(_scan_has("FrameBadShape.untyped must take one float"), "an untyped argument is rejected")
	assert_true(_scan_has("FrameNode.tick is @Process on a Node"), "a node keeps _process")
	assert_true(_scan_has("FrameNode.phys is @PhysicsProcess on a Node"), "a node keeps _physics_process")
	assert_true(_scan_has("FrameConfig.tick is @Process on a configuration"), "a configuration method is rejected")
	assert_true(_scan_has("@PhysicsProcess on FrameConfig belongs on a method"), "a configuration class mark is rejected")
	var shape := box.resolve(FrameBadShape) as FrameBadShape
	box.run_process(0.1)
	box.run_physics_process(0.1)
	assert_not_null(shape, "the component is still constructed")


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
