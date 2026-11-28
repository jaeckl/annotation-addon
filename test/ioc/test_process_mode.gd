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
		if text.find("ProcessMode") != -1:
			scan_errors.append(text)
		err.handled = true


func after_each() -> void:
	if box != null:
		box.shutdown()
	box = null
	for child in get_tree().root.get_children():
		if child.name == "AsyncRoom" or child is ModeBolt:
			child.free()


func _has(fragment: String) -> bool:
	for line in scan_errors:
		if line.find(fragment) != -1:
			return true
	return false


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


func test_attach_sets_the_marked_mode() -> void:
	var menu := box.resolve(ModeMenu) as ModeMenu
	assert_not_null(menu, "ModeMenu resolves")
	assert_eq(menu.process_mode, Node.PROCESS_MODE_WHEN_PAUSED, "attach applies @ProcessMode before parenting")


func test_pooled_borrow_honors_the_mark() -> void:
	var room := _room()
	var pools := box.resolve(InstancePools) as InstancePools
	var bolt := pools.borrow(ModeBolt, room) as ModeBolt
	assert_eq(bolt.process_mode, Node.PROCESS_MODE_ALWAYS, "borrow applies @ProcessMode")
	pools.release(bolt)
	assert_eq(bolt.process_mode, Node.PROCESS_MODE_DISABLED, "park still disables")
	var again := pools.borrow(ModeBolt, room) as ModeBolt
	assert_eq(again.process_mode, Node.PROCESS_MODE_ALWAYS, "re-borrow restores the mark")
	pools.release(again)
	room.free()


func test_scan_rejects_bad_shapes() -> void:
	assert_true(_has("ModePlain is @ProcessMode and is not a Node"), "RefCounted cannot take @ProcessMode")
	assert_true(_has("ModeOrphan is @ProcessMode without @Component"), "needs @Component")
	assert_true(_has("@ProcessMode on ModeMember belongs on a class"), "field is illegal")
