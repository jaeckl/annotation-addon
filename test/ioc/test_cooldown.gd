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
		if text.find("Cooldown") != -1 or text.find("OncePer") != -1:
			scan_errors.append(text)
		err.handled = true


func after_each() -> void:
	if box != null:
		box.shutdown()
	box = null


func _has(fragment: String) -> bool:
	for line in scan_errors:
		if line.find(fragment) != -1:
			return true
	return false


func test_cooldown_gates_process_calls() -> void:
	var gun := box.resolve(CoolGun) as CoolGun
	assert_not_null(gun, "CoolGun resolves")
	box.run_cooldowns(0.0)
	box.run_process(0.1)
	assert_eq(gun.shots, [0.1], "first call runs")
	box.run_cooldowns(0.4)
	box.run_process(0.2)
	assert_eq(gun.shots, [0.1], "still cooling down")
	box.run_cooldowns(0.6)
	box.run_process(0.3)
	assert_eq(gun.shots, [0.1, 0.3], "opens after one second of idle time")


func test_once_per_frame_dedupes() -> void:
	var click := box.resolve(CoolClick) as CoolClick
	assert_not_null(click, "CoolClick resolves")
	box.run_cooldowns(0.0)
	click.tap()
	click.tap()
	assert_eq(click.hits, 1, "second tap in the same frame is gated")
	box.run_cooldowns(0.0)
	click.tap()
	assert_eq(click.hits, 2, "next idle frame allows another tap")


func test_scan_rejects_bad_shapes() -> void:
	assert_true(_has("CoolBadCron.fire @Cooldown needs a delay"), "cron is not a cooldown")
	assert_true(_has("CoolBadBoth.fire cannot be @Cooldown and @OncePer"), "one gate only")
	assert_true(_has("CoolBadOnce.fire @OncePer needs frame or physics_frame"), "bad once value")
