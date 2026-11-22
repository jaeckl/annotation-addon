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
		if text.find("Ready") != -1 or text.find("OnDestroy") != -1 or text.find("must take nothing") != -1 or text.find("pooled") != -1:
			scan_errors.append(text)
		err.handled = true


func after_each() -> void:
	if box != null:
		box.shutdown()
	box = null
	for child in get_tree().root.get_children():
		if child.name == "AsyncRoom":
			child.free()


func test_ready_runs_once_after_inject() -> void:
	var reader := box.resolve(LifeReader) as LifeReader
	assert_eq(reader.log.lines, ["ready:clock", "ready:reader"], "a dependency is ready before the product that needs it")
	box.resolve(LifeReader)
	assert_eq(reader.log.lines, ["ready:clock", "ready:reader"], "ready runs once")
	var horn := box.resolve(LifeHorn) as LifeHorn
	assert_eq(horn.heard, 1, "ready runs after the product's listeners are armed")


func test_destroy_is_reverse_publish_order() -> void:
	var reader := box.resolve(LifeReader) as LifeReader
	box.shutdown()
	assert_eq(reader.log.lines, ["ready:clock", "ready:reader", "down:reader", "down:clock"], "a dependent is destroyed before its dependency")


func test_methods_keep_source_order_and_base_order() -> void:
	var derived := box.resolve(LifeDerived) as LifeDerived
	assert_eq(derived.log, ["ready:derived", "ready:base"], "ready methods run derived then base")
	box.shutdown()
	assert_eq(derived.log, ["ready:derived", "ready:base", "down:derived", "down:base"], "destroy methods on one product stay in source order")


func test_a_scene_product_leaves_with_the_scene() -> void:
	var pulse := box.resolve(LifePulse) as LifePulse
	var packed := load("res://test/ioc/async_room.tscn") as PackedScene
	var room := packed.instantiate()
	add_child(room)
	_handle_scene_noise()
	var scene := box.resolve(LifeScene, [], room) as LifeScene
	assert_eq(scene.ready_hits, 1, "the scene product is ready when it is published")
	assert_eq(pulse.ready_hits, 1, "the app product was already ready")
	room.free()
	_handle_scene_noise()
	assert_eq(scene.destroy_hits, 1, "the scene product is destroyed with the root")
	assert_eq(pulse.destroy_hits, 0, "the app product stays")
	box.shutdown()
	assert_eq(scene.destroy_hits, 1, "shutdown does not destroy the scene product again")
	assert_eq(pulse.destroy_hits, 1, "shutdown destroys the app product")


func test_shutdown_destroys_an_open_scene_product_once() -> void:
	var packed := load("res://test/ioc/async_room.tscn") as PackedScene
	var room := packed.instantiate()
	add_child(room)
	_handle_scene_noise()
	var scene := box.resolve(LifeScene, [], room) as LifeScene
	box.shutdown()
	assert_eq(scene.destroy_hits, 1, "shutdown destroys a scene product that is still open")
	room.free()
	_handle_scene_noise()
	assert_eq(scene.destroy_hits, 1, "leaving afterwards does not destroy it again")


func test_advice_wraps_ready() -> void:
	var log := box.resolve(CallLog) as CallLog
	var woven := box.resolve(LifeWoven) as LifeWoven
	assert_eq(woven.ran, 1, "the method ran")
	assert_eq(log.calls[0], "before:boot:[]", "advice sees the call")
	assert_eq(log.calls[1], "around:boot", "around wraps the call")
	assert_eq(log.calls[2], "after:boot:<null>", "after sees the return")


func test_ready_that_awaits_is_rejected() -> void:
	var waiting := box.resolve(LifeAwait) as LifeAwait
	assert_eq(waiting.started, 1, "the method started")
	assert_engine_error("LifeAwait.boot cannot await")
	waiting.resume.emit()


func test_bad_marks_are_rejected() -> void:
	assert_eq(_count("@Ready on LifeBad belongs on a method."), 3, "a class, a field, and a parameter are rejected")
	assert_true(_has("LifeBad.parked is static and cannot use @OnDestroy."), "a static method is rejected")
	assert_true(_has("LifeBad.takes must take nothing."), "a method with arguments is rejected")
	assert_true(_has("LifeNode.boot is @Ready on a Node."), "a node keeps _ready")
	assert_true(_has("LifeNode.down is @OnDestroy on a Node."), "a node keeps tree exit")
	assert_true(_has("LifeConfig.boot is @Ready on a configuration."), "a configuration method is rejected")
	assert_true(_has("LifeConfig.down is @OnDestroy on a configuration."), "a configuration destroy method is rejected")
	assert_true(_has("@Ready on LifeConfig belongs on a method."), "a configuration class mark is rejected")
	assert_true(_has("LifePooled.boot is @Ready and LifePooled is pooled."), "a pooled class is not published")
	assert_true(_has("LifePooled.down is @OnDestroy and LifePooled is pooled."), "a pooled class uses @OnRelease")
	assert_not_null(box.resolve(LifeBad), "the component is still constructed")


func _has(needle: String) -> bool:
	return _count(needle) > 0


func _count(needle: String) -> int:
	var found := 0
	for text in scan_errors:
		if text.find(needle) != -1:
			found += 1
	return found


func _handle_scene_noise() -> void:
	for err in get_errors():
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("NoSuchAddon") != -1 or text.find("not a global class") != -1:
			err.handled = true
