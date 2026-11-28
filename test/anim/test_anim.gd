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
		if text.find("Anim:") != -1 or text.find("TweenPlay") != -1 or text.find("OnAnim") != -1:
			scan_errors.append(text)
		err.handled = true


func after_each() -> void:
	if box != null:
		box.shutdown()
	box = null
	for child in get_tree().root.get_children():
		if child is AnimBadBoth:
			child.free()


func _has(fragment: String) -> bool:
	for line in scan_errors:
		if line.find(fragment) != -1:
			return true
	return false


func _pump_until(ok: Callable, frames: int = 60) -> bool:
	for _i in frames:
		if ok.call():
			return true
		await get_tree().process_frame
	return ok.call()


func test_tween_play_runs_on_call() -> void:
	var flash := box.resolve(TweenFlash) as TweenFlash
	assert_not_null(flash, "TweenFlash resolves")
	await get_tree().process_frame
	flash.modulate.a = 1.0
	flash.flash()
	assert_eq(flash.body_ran, 1, "method body still runs")
	var moved: bool = await _pump_until(func() -> bool: return flash.modulate.a < 0.5)
	assert_true(moved, "tween moved modulate.a toward 0")


func test_on_anim_started_and_finished() -> void:
	var host := box.resolve(AnimHost) as AnimHost
	assert_not_null(host, "AnimHost resolves")
	await get_tree().process_frame
	var player := host.get_node("AnimationPlayer") as AnimationPlayer
	assert_not_null(player, "player was added in _ready")
	player.play("wave")
	assert_eq(host.started_hits, 1, "started fired")
	var done: bool = await _pump_until(func() -> bool: return host.finished_hits >= 1)
	assert_true(done, "finished fired")


func test_scan_rejects_bad_shapes() -> void:
	assert_true(_has("TweenBadPlain.flash is @TweenPlay and is not a Node"), "RefCounted cannot tween")
	assert_true(_has("AnimBadBoth.bad @OnAnim needs exactly one of on_finished or on_started"), "one event kind")
