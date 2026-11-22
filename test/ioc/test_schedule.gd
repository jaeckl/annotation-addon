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
		if text.find("Scheduled") != -1 or text.find("schedule") != -1 or text.find("whole number") != -1 or text.find("must take nothing") != -1:
			scan_errors.append(text)
		err.handled = true


func after_each() -> void:
	get_tree().paused = false
	if box != null:
		box.shutdown()
	box = null
	for child in get_tree().root.get_children():
		if child.name == "AsyncRoom":
			child.free()


func test_delays_wait_one_period_and_do_not_burst() -> void:
	var clock := box.resolve(ScheduleClock) as ScheduleClock
	box.run_scheduled(0.4)
	assert_eq(clock.ms, 0, "500ms has not elapsed")
	assert_eq(clock.seconds, 0, "one second has not elapsed")
	box.run_scheduled(0.1)
	assert_eq(clock.ms, 1, "500ms elapses on the idle clock")
	assert_eq(clock.seconds, 0, "one second is still waiting")
	box.run_scheduled(0.5)
	assert_eq(clock.seconds, 1, "one second elapses from idle delta")
	var before := clock.ms
	box.run_scheduled(2.0)
	assert_eq(clock.ms, before + 1, "a long delta calls the method once")


func test_frames_count_on_their_own_clocks() -> void:
	var clock := box.resolve(ScheduleClock) as ScheduleClock
	box.run_scheduled(0.0)
	box.run_scheduled(0.0)
	assert_eq(clock.frames, 0, "three idle frames have not passed")
	assert_eq(clock.both, 3, "the one-frame and two-frame marks have both fired")
	assert_eq(clock.physics, 0, "physics frames wait for the physics clock")
	box.run_scheduled(0.0)
	assert_eq(clock.frames, 1, "the third idle frame fires")
	box.run_scheduled_physics()
	assert_eq(clock.physics, 0, "one physics frame is short of two")
	box.run_scheduled_physics()
	assert_eq(clock.physics, 1, "the second physics frame fires")
	assert_eq(clock.frames, 1, "a physics frame does not count as an idle frame")


func test_methods_run_in_source_order_then_base_order() -> void:
	var order := box.resolve(ScheduleOrder) as ScheduleOrder
	var derived := box.resolve(ScheduleDerived) as ScheduleDerived
	box.run_scheduled(0.0)
	assert_eq(order.log, ["first", "second"], "methods on one product run in source order")
	assert_eq(derived.log, ["derived", "base"], "a base method runs after the derived method")


func test_cron_fires_once_per_observed_second() -> void:
	var cron := box.resolve(ScheduleCron) as ScheduleCron
	box.run_scheduled(0.0)
	box.run_scheduled(0.0)
	assert_eq(cron.hits, 1, "the current second fires once")


func test_a_cron_field_matches_numbers_steps_and_either_day() -> void:
	var each_five := ScheduleSpec.parse("*/5 * * * * *")
	assert_eq(each_five.error, "", "a step is a schedule")
	assert_true(each_five.matches(_now(0)), "a step includes the start of the field")
	assert_true(each_five.matches(_now(5)), "a step includes the next value")
	assert_false(each_five.matches(_now(1)), "a step skips the values between")
	var noon := ScheduleSpec.parse("0 0 12 * * *")
	assert_true(noon.matches(_now(0, 0, 12)), "a number matches that value")
	assert_false(noon.matches(_now(0, 0, 11)), "a number rejects another hour")
	var either := ScheduleSpec.parse("0 0 0 1 * 1")
	assert_true(either.matches(_now(0, 0, 0, 2, 1)), "a restricted weekday matches on its own")
	assert_true(either.matches(_now(0, 0, 0, 1, 3)), "a restricted day of month matches on its own")
	assert_false(either.matches(_now(0, 0, 0, 2, 3)), "neither day matches")
	var sunday := ScheduleSpec.parse("0 0 0 * * 7")
	assert_true(sunday.matches(_now(0, 0, 0, 1, 0)), "7 is Sunday")
	assert_false(sunday.matches(_now(0, 0, 0, 1, 1)), "Monday is not Sunday")


func test_the_frame_node_pauses_with_the_tree() -> void:
	var pulse := box.resolve(SchedulePulse) as SchedulePulse
	get_tree().paused = true
	await get_tree().process_frame
	assert_eq(pulse.hits, 0, "a paused tree skips the schedule")
	get_tree().paused = false
	await get_tree().process_frame
	assert_eq(pulse.hits, 1, "the next idle frame fires one call")


func test_a_scene_schedule_leaves_with_the_scene() -> void:
	var packed := load("res://test/ioc/async_room.tscn") as PackedScene
	var room := packed.instantiate()
	add_child(room)
	_handle_scene_noise()
	var scene := box.resolve(ScheduleScene, [], room) as ScheduleScene
	var pulse := box.resolve(SchedulePulse) as SchedulePulse
	box.run_scheduled(0.0)
	assert_eq(scene.hits, 1, "the scene product runs while the root is open")
	assert_eq(pulse.hits, 1, "an app product runs in the same pass")
	room.free()
	_handle_scene_noise()
	box.run_scheduled(0.0)
	assert_eq(scene.hits, 1, "the scene product stops when the root leaves")
	assert_eq(pulse.hits, 2, "the app product keeps running")


func test_advice_wraps_a_scheduled_method() -> void:
	var log := box.resolve(CallLog) as CallLog
	var woven := box.resolve(ScheduleWoven) as ScheduleWoven
	box.run_scheduled(0.0)
	assert_eq(woven.ran, 1, "the method ran")
	assert_eq(log.calls[0], "before:tick:[]", "advice sees the call")
	assert_eq(log.calls[1], "around:tick", "around wraps the call")
	assert_eq(log.calls[2], "after:tick:<null>", "after sees the return")


func test_a_schedule_that_awaits_is_rejected() -> void:
	var waiting := box.resolve(ScheduleAwait) as ScheduleAwait
	box.run_scheduled(0.0)
	assert_eq(waiting.started, 1, "the method started")
	assert_engine_error("ScheduleAwait.tick cannot await")
	waiting.resume.emit()


func test_bad_marks_are_rejected() -> void:
	assert_true(_has("@Scheduled on ScheduleBad belongs on a method."), "a class, a field, and a parameter are rejected")
	assert_true(_has("ScheduleBad.empty schedule is empty."), "an empty string is rejected")
	assert_true(_has("ScheduleBad.zero schedule must be greater than 0."), "zero is rejected")
	assert_true(_has("ScheduleBad.negative schedule must be greater than 0."), "a negative delay is rejected")
	assert_true(_has("ScheduleBad.fraction must be a whole number of frames."), "a fractional frame is rejected")
	assert_true(_has("ScheduleBad.garbage is not a schedule."), "an unknown string is rejected")
	assert_true(_has("ScheduleBad.bad_cron is not a schedule."), "a cron field outside its range is rejected")
	assert_true(_has("ScheduleBad.parked is static and cannot be scheduled."), "a static method is rejected")
	assert_true(_has("ScheduleBad.takes must take nothing."), "a method with arguments is rejected")
	assert_true(_has("ScheduleNode.tick is @Scheduled on a Node."), "a node keeps its own callbacks")
	assert_true(_has("ScheduleConfig.tick is @Scheduled on a configuration."), "a configuration method is rejected")
	assert_true(_has("@Scheduled on ScheduleConfig belongs on a method."), "a configuration class mark is rejected")
	assert_not_null(box.resolve(ScheduleBad), "the component is still constructed")


func _now(second: int, minute: int = 0, hour: int = 0, day: int = 1, weekday: int = 0) -> Dictionary:
	return {
		"second": second,
		"minute": minute,
		"hour": hour,
		"day": day,
		"month": 1,
		"weekday": weekday,
	}


func _has(needle: String) -> bool:
	for text in scan_errors:
		if text.find(needle) != -1:
			return true
	return false


func _handle_scene_noise() -> void:
	for err in get_errors():
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("NoSuchAddon") != -1 or text.find("not a global class") != -1:
			err.handled = true
