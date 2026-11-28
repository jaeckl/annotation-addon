extends GutTest

const ROOM := "res://test/ioc/async_room.tscn"
const VISIT := "res://test/ioc/visit_room.tscn"

var box: IOCContainer
var scan_errors: PackedStringArray = PackedStringArray()


func before_each() -> void:
	ProjectSettings.set_setting("ioc/scene_scope_fixtures", "yes")
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	scan_errors = PackedStringArray()
	for err in get_errors():
		if err.handled:
			continue
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("SceneScoped") != -1 or text.find("SceneScope") != -1:
			scan_errors.append(text)
		err.handled = true


func after_each() -> void:
	ProjectSettings.set_setting("ioc/scene_scope_fixtures", "")
	if box != null:
		box.shutdown()
	box = null
	_free_rooms()
	await get_tree().process_frame


func test_a_scene_scoped_product_needs_an_open_scene() -> void:
	assert_null(box.resolve(ScopeRoom), "nothing is built")
	assert_push_error("ScopeRoom is scene scoped and no scene is open.")


func test_one_instance_lives_for_one_scene() -> void:
	var room := _open(ROOM)
	var first := box.resolve(ScopeRoom, [], room) as ScopeRoom
	assert_not_null(first, "the product builds")
	assert_eq(box.resolve(ScopeRoom, [], room), first, "a second resolve returns the same instance")
	assert_eq(first.ready_hits, 1, "ready runs once")
	room.free()
	_handle_noise()
	var visit := _open(VISIT)
	var second := box.resolve(ScopeRoom, [], visit) as ScopeRoom
	assert_ne(second, first, "a new scene builds a new instance")
	assert_eq(first.destroy_hits, 1, "the old product left with its root")
	assert_eq(second.ready_hits, 1, "the new product is ready")


func test_an_app_product_cannot_inject_a_scene_product() -> void:
	var room := _open(ROOM)
	assert_null(box.resolve(ScopeKeeper, [], room), "the app product is not built")
	assert_push_error("ScopeKeeper outlives the scene and cannot hold ScopeRoom.")
	assert_push_error("missing field room on ScopeKeeper.")


func test_a_scene_product_may_inject_another() -> void:
	var room := _open(ROOM)
	var peer := box.resolve(ScopePeer, [], room) as ScopePeer
	assert_not_null(peer, "the peer builds")
	assert_eq(peer.room, box.resolve(ScopeRoom, [], room), "both share the scene instance")


func test_node_conditioned_products_still_use_the_handler() -> void:
	var room := _open(ROOM)
	var scene := box.resolve(LifeScene, [], room) as LifeScene
	assert_not_null(scene, "node-conditioned products still resolve")
	assert_true(box.scene_scope.has_root(room.get_instance_id()), "the handler tracks the root")
	var stored := false
	for instance in box.scene_scope.instances_of(room.get_instance_id()).values():
		if instance == scene:
			stored = true
			break
	assert_true(stored, "the handler stores the node-conditioned instance")


func test_bad_marks_are_rejected() -> void:
	assert_true(_has("ScopeBadPlain is @SceneScoped without @Component."), "the mark needs a product")
	assert_true(_has("@SceneScoped on ScopeBadMember belongs on a class or a factory method."), "a field is refused")
	assert_true(_has("ScopeBadMember.ping is @SceneScoped and is not a factory method."), "a plain method is refused")
	assert_true(_has("ScopeBadBoth is @RunScope and @SceneScoped."), "two scopes are refused")


func _open(path: String) -> Node:
	var packed := load(path) as PackedScene
	var room := packed.instantiate()
	add_child(room)
	_handle_noise()
	return room


func _free_rooms() -> void:
	for child in get_tree().root.get_children():
		if child.name == "AsyncRoom" or child.name == "VisitRoom":
			child.free()
	_handle_noise()


func _handle_noise() -> void:
	for err in get_errors():
		err.handled = true


func _has(needle: String) -> bool:
	for text in scan_errors:
		if text.find(needle) != -1:
			return true
	return false
