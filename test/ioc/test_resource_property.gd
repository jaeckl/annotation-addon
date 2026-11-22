extends GutTest

const ROOM := "res://test/ioc/async_room.tscn"
const PAGE := "res://test/ioc/settings/kit_page.tres"

var box: IOCContainer
var scan_errors: PackedStringArray = PackedStringArray()


func before_each() -> void:
	box = IOCContainer.new()
	box.setup(get_tree())
	scan_errors = PackedStringArray()


func after_each() -> void:
	if box != null:
		box.shutdown()
	box = null


func test_a_path_loads_a_subclass_and_keeps_a_missing_default() -> void:
	_put({
		"kit/room": ROOM,
		"kit/note": PAGE,
		"kit/any": ROOM,
		"kit/pace": "slow",
		"kit/title": "Town",
	})
	_discover()
	var kit := box.resolve(KitSettings) as KitSettings
	assert_not_null(kit, "the settings object is published")
	assert_eq(kit.room.resource_path, ROOM, "a res:// path loads the packed scene")
	assert_true(kit.note is KitPage, "a subclass fills the base field")
	assert_eq(kit.note.text, "hello", "the loaded resource keeps its fields")
	assert_true(kit.any is PackedScene, "a Resource field accepts the scene")
	assert_null(kit.clip, "a missing key keeps the field default")
	assert_eq(kit.pace, 1, "a custom converter still wins for its own type")
	assert_eq(kit.title, "Town", "a string still binds on the same object")
	var reader := box.resolve(KitReader) as KitReader
	assert_same(reader.kit, kit, "gameplay receives the settings object")


func test_an_existing_resource_passes_through() -> void:
	var scene := load(ROOM) as PackedScene
	_put({"kit/room": scene})
	_discover()
	var kit := box.resolve(KitSettings) as KitSettings
	assert_same(kit.room, scene, "a resource already of the field class is kept")


func test_the_winning_source_is_the_one_that_loads() -> void:
	var low := MapPropertySource.new()
	low.fill({"kit/room": "res://test/ioc/missing_room.tscn"})
	var high := MapPropertySource.new()
	high.fill({"kit/room": ROOM})
	box.environment.add_first(low)
	box.environment.add_first(high)
	_discover()
	var kit := box.resolve(KitSettings) as KitSettings
	assert_eq(kit.room.resource_path, ROOM, "the first source supplies the path")


func test_a_missing_file_drops_the_product() -> void:
	_put({"kit/room": "res://test/ioc/missing_room.tscn"})
	_discover()
	assert_true(_has("KitSettings.room res://test/ioc/missing_room.tscn did not load."), "a missing file is rejected")
	assert_null(box.resolve(KitSettings), "the settings object is not published")
	assert_engine_error("no component for KitSettings")


func test_the_wrong_class_drops_the_product() -> void:
	_put({"kit/clip": ROOM})
	_discover()
	assert_true(_has("KitSettings.clip is not AudioStream."), "a packed scene is not an audio stream")
	assert_null(box.resolve(KitSettings), "the settings object is not published")
	assert_engine_error("no component for KitSettings")


func test_a_stored_resource_of_the_wrong_class_drops_the_product() -> void:
	_put({"kit/clip": load(ROOM)})
	_discover()
	assert_true(_has("KitSettings.clip is not AudioStream."), "the stored resource must match the field")
	assert_null(box.resolve(KitSettings), "the settings object is not published")
	assert_engine_error("no component for KitSettings")


func test_a_path_outside_res_drops_the_product() -> void:
	_put({"kit/room": "user://room.tscn"})
	_discover()
	assert_true(_has("KitSettings.room must be a res:// path."), "another scheme is rejected")
	assert_null(box.resolve(KitSettings), "the settings object is not published")
	assert_engine_error("no component for KitSettings")


func test_a_node_or_array_field_is_rejected() -> void:
	_discover()
	var node := KitNode.new()
	assert_false(box.binder.bind(node, "kit", _environment({})), "a node is not a settings value")
	node.free()
	assert_engine_error("KitNode.marker must be int, float, bool, String, or Resource.")
	assert_false(box.binder.bind(KitList.new(), "kit", _environment({})), "an array is not a settings value")
	assert_engine_error("KitList.rooms must be int, float, bool, String, or Resource.")


func _put(values: Dictionary) -> void:
	box.environment.add_first(_source(values))


func _environment(values: Dictionary) -> PropertyEnvironment:
	var environment := PropertyEnvironment.new()
	environment.add_first(_source(values))
	return environment


func _source(values: Dictionary) -> MapPropertySource:
	var source := MapPropertySource.new()
	source.fill(values)
	return source


func _discover() -> void:
	box.discover()
	scan_errors = PackedStringArray()
	for err in get_errors():
		if err.handled:
			continue
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("KitSettings") != -1:
			scan_errors.append(text)
		err.handled = true


func _has(needle: String) -> bool:
	for text in scan_errors:
		if text.find(needle) != -1:
			return true
	return false
