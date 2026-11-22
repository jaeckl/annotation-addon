extends GutTest

var box: IOCContainer
var scene_errors: PackedStringArray = PackedStringArray()


func before_each() -> void:
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	scene_errors = PackedStringArray()
	for err in get_errors():
		if err.handled:
			continue
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("Scene") != -1 or text.find("scene root") != -1 or text.find("did not load") != -1 or text.find("constructor arguments") != -1:
			scene_errors.append(text)
		err.handled = true


func after_each() -> void:
	if box != null:
		box.shutdown()
	box = null
	for child in get_tree().root.get_children():
		if child.name == "AsyncRoom" or child.name == "SpawnBolt" or child.name == "SpawnShot" or child is SpawnBolt or child is SpawnShot:
			child.free()


func test_resolve_instantiates_the_scene() -> void:
	var bolt := box.resolve(SpawnBolt) as SpawnBolt
	var clock := box.resolve(SpawnClock) as SpawnClock
	assert_eq(bolt.hits, 1, "the root is injected before it enters")
	assert_eq(bolt.clock, clock, "the root receives the clock")
	assert_true(bolt.has_node("Tip"), "the scene children are present")
	await get_tree().process_frame
	_handle_scene_noise()
	assert_eq(bolt.get_parent(), get_tree().root, "the scope parents the root")
	var tip := bolt.get_node("Tip") as SpawnTip
	assert_eq(tip.hits, 1, "a child is filled when it enters")
	assert_eq(tip.clock, clock, "the child receives the same clock")
	assert_eq(box.resolve(SpawnBolt), bolt, "resolve stays one instance")


func test_borrow_instantiates_a_pooled_scene() -> void:
	var room := _room()
	var pools := box.resolve(InstancePools) as InstancePools
	var shot := pools.borrow(SpawnShot, room) as SpawnShot
	_handle_scene_noise()
	var id := shot.get_instance_id()
	assert_true(shot.has_node("Mark"), "borrow instantiates the scene")
	assert_eq(shot.get_parent(), room, "the caller is the parent")
	shot.token = 3
	pools.release(shot)
	_handle_scene_noise()
	assert_eq(shot.get_parent().name, "IocPool", "release parks the scene root")
	assert_true(shot.has_node("Mark"), "the children stay under the parked root")
	var again := pools.borrow(SpawnShot, room) as SpawnShot
	_handle_scene_noise()
	assert_eq(again.get_instance_id(), id, "the same scene comes back")
	assert_eq(again.token, 3, "the caller's fields survive")
	assert_eq(again.get_parent(), room, "borrow reparents the scene")


func test_resolve_refuses_a_pooled_scene() -> void:
	assert_null(box.resolve(SpawnShot), "resolve does not hand out a pooled scene")
	assert_engine_error("SpawnShot is pooled. Borrow it.")


func test_a_painted_scene_script_is_rejected() -> void:
	var stray := SpawnBolt.new()
	get_tree().root.add_child(stray)
	assert_engine_error("SpawnBolt is in a scene and is also @Component.")


func test_scene_without_a_component_is_rejected() -> void:
	assert_true(_has("SpawnPlain is @Scene without @Component."), "a class mark needs @Component")


func test_scene_on_a_method_is_rejected() -> void:
	assert_true(_has("@Scene on SpawnMethod belongs on a class."), "the mark is not a method mark")


func test_scene_on_a_configuration_is_rejected() -> void:
	assert_true(_has("SpawnConfig is @Scene on a configuration."), "a configuration is not a scene product")


func test_a_refcounted_scene_is_rejected() -> void:
	assert_true(_has("SpawnRef is @Scene and is not a Node."), "a packed scene root is a node")


func test_a_missing_scene_is_rejected() -> void:
	assert_true(_has("SpawnMissing scene res://test/ioc/spawn_clock.gd did not load."), "the path has to be a packed scene")


func test_a_wrong_root_script_is_rejected() -> void:
	assert_true(_has("SpawnWrong scene root is not SpawnWrong."), "the root script is the component")


func test_scene_constructor_arguments_are_rejected() -> void:
	assert_true(_has("SpawnInit is a scene and cannot take constructor arguments."), "instantiate takes no arguments")


func test_an_empty_scene_path_is_rejected() -> void:
	assert_true(_has("@Scene on SpawnEmpty needs a path."), "the path is required")


func _room() -> Node:
	var packed := load("res://test/ioc/async_room.tscn") as PackedScene
	var room := packed.instantiate()
	get_tree().root.add_child(room)
	_handle_scene_noise()
	return room


func _handle_scene_noise() -> void:
	for err in get_errors():
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("NoSuchAddon") != -1 or text.find("not a global class") != -1:
			err.handled = true


func _has(needle: String) -> bool:
	for text in scene_errors:
		if text.find(needle) != -1:
			return true
	return false
