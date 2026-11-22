extends GutTest

const ROOM := "res://test/ioc/async_room.tscn"
const VISIT := "res://test/ioc/visit_room.tscn"

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
		if text.find("OnSceneEnter") != -1 or text.find("OnSceneExit") != -1 or text.find("must take one Node") != -1 or text.find("scene product") != -1:
			scan_errors.append(text)
		err.handled = true


func after_each() -> void:
	if box != null:
		box.shutdown()
	box = null
	_free_rooms()


func _free_rooms() -> void:
	var pending: Array = []
	_find_rooms(get_tree().root, pending)
	for node in pending:
		if is_instance_valid(node):
			node.free()
	_handle_scene_noise()


func _find_rooms(node: Node, pending: Array) -> void:
	if node.name == "AsyncRoom" or node.name == "VisitRoom":
		pending.append(node)
		return
	for child in node.get_children():
		_find_rooms(child, pending)


func test_enter_follows_publish_order_and_exit_reverses_scenes() -> void:
	var late := box.resolve(VisitLate) as VisitLate
	_open(ROOM)
	_open(VISIT)
	assert_eq(_named(late.book.lines), ["early:AsyncRoom", "late:AsyncRoom", "early:VisitRoom", "late:VisitRoom"], "enter follows publish order, then open order")
	var seen := _named(late.book.lines).size()
	box.resolve(VisitLate)
	assert_eq(_named(late.book.lines).size(), seen, "a second resolve does not enter again")
	box.shutdown()
	assert_eq(_named(late.book.lines), [
		"early:AsyncRoom", "late:AsyncRoom", "early:VisitRoom", "late:VisitRoom",
		"early-exit:VisitRoom", "late-exit:VisitRoom", "early-exit:AsyncRoom", "late-exit:AsyncRoom",
	], "the last opened scene exits first")
	seen = _named(late.book.lines).size()
	_free_rooms()
	assert_eq(_named(late.book.lines).size(), seen, "leaving after shutdown does not exit again")


func test_a_product_published_into_an_open_scene_enters() -> void:
	_open(ROOM)
	var late := box.resolve(VisitLate) as VisitLate
	assert_eq(_named(late.book.lines), ["early:AsyncRoom", "late:AsyncRoom"], "an open scene is visible when the product is published")


func test_methods_keep_source_order_and_base_order() -> void:
	var derived := box.resolve(VisitDerived) as VisitDerived
	var before := derived.log.size()
	_open(ROOM)
	assert_eq(derived.log.slice(before), ["derived", "base"], "a base method runs after the derived method")


func test_a_node_subclass_receives_only_that_root() -> void:
	var picky := box.resolve(VisitPicky) as VisitPicky
	_open(ROOM)
	assert_false(picky.names.has("AsyncRoom"), "a plain node is not a Node2D")
	_open(VISIT)
	assert_true(picky.names.has("VisitRoom"), "a Node2D root reaches the method")


func test_advice_wraps_enter() -> void:
	var log := box.resolve(CallLog) as CallLog
	var woven := box.resolve(VisitWoven) as VisitWoven
	var before := woven.ran
	var calls := log.calls.size()
	_open(ROOM)
	assert_eq(woven.ran, before + 1, "the method ran")
	assert_true(String(log.calls[calls]).begins_with("before:entered:"), "advice sees the call")
	assert_eq(log.calls[calls + 1], "around:entered", "around wraps the call")
	assert_true(String(log.calls[calls + 2]).begins_with("after:entered:"), "after sees the return")


func test_enter_that_awaits_is_rejected() -> void:
	var waiting := box.resolve(VisitAwait) as VisitAwait
	var before := waiting.started
	_open(ROOM)
	assert_eq(waiting.started, before + 1, "the method started")
	assert_true(_take_errors("VisitAwait.entered cannot await") > 0, "an await is rejected")
	waiting.resume.emit()


func test_a_scene_product_does_not_see_the_scene() -> void:
	var room := _open(ROOM)
	var scene := box.resolve(VisitScene, [], room) as VisitScene
	assert_eq(scene.hits, 0, "the method is not called")
	assert_engine_error("VisitScene.entered is @OnSceneEnter on a scene product.")
	assert_engine_error("VisitScene.left is @OnSceneExit on a scene product.")


func test_bad_marks_are_rejected() -> void:
	assert_eq(_count("@OnSceneEnter on VisitBad belongs on a method."), 3, "a class, a field, and a parameter are rejected")
	assert_true(_has("VisitBad.parked is static and cannot use @OnSceneExit."), "a static method is rejected")
	assert_true(_has("VisitBad.takes must take one Node."), "a method with no arguments is rejected")
	assert_true(_has("VisitBad.named must take one Node."), "a method that does not take a Node is rejected")
	assert_true(_has("VisitNode.entered is @OnSceneEnter on a Node."), "a node keeps the tree")
	assert_true(_has("VisitNode.left is @OnSceneExit on a Node."), "a node keeps tree exit")
	assert_true(_has("VisitConfig.entered is @OnSceneEnter on a configuration."), "a configuration method is rejected")
	assert_true(_has("VisitConfig.left is @OnSceneExit on a configuration."), "a configuration exit method is rejected")
	assert_true(_has("@OnSceneEnter on VisitConfig belongs on a method."), "a configuration class mark is rejected")
	assert_true(_has("VisitPooled.entered is @OnSceneEnter and VisitPooled is pooled."), "a pooled class is not published")
	assert_true(_has("VisitPooled.left is @OnSceneExit and VisitPooled is pooled."), "a pooled class is not published")
	assert_not_null(box.resolve(VisitBad), "the component is still constructed")


func _named(lines: Array) -> Array:
	var kept: Array = []
	for line in lines:
		var text := String(line)
		if text.find("AsyncRoom") != -1 or text.find("VisitRoom") != -1:
			kept.append(text)
	return kept


func _take_errors(needle: String) -> int:
	var found := 0
	for err in get_errors():
		if err.handled:
			continue
		var text := "%s %s" % [err.code, err.rationale]
		if text.find(needle) == -1:
			continue
		found += 1
		err.handled = true
	return found


func _open(path: String) -> Node:
	var packed := load(path) as PackedScene
	var room := packed.instantiate()
	add_child(room)
	_handle_scene_noise()
	return room


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
