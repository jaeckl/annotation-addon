extends GutTest

## Pending-slot continue: load on scene open before @SceneScoped builds.

const ROOM := "res://test/ioc/async_room.tscn"

var box: IOCContainer
var runs: Runs
var slots: SaveSlots
var pools: InstancePools
var _slot_root: String = ""


func before_each() -> void:
	_slot_root = "user://save_continue_%s" % Time.get_ticks_usec()
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	_handle_noise()
	runs = box.resolve(Runs) as Runs
	slots = box.resolve(SaveSlots) as SaveSlots
	pools = box.resolve(InstancePools) as InstancePools
	assert_not_null(slots, "SaveSlots published")
	assert_not_null(box.resolve(SaveContinueHook), "SaveContinueHook published")
	slots.root = _slot_root


func after_each() -> void:
	if box != null:
		box.shutdown()
	box = null
	runs = null
	slots = null
	pools = null
	_wipe_root(_slot_root)
	_free_rooms()
	await get_tree().process_frame


func test_pending_slot_loads_when_scene_opens() -> void:
	var room := _open(ROOM)
	slots.body_parent = room
	assert_true(runs.start(), "run opens")
	var party := box.resolve(KeptParty) as KeptParty
	var mob := pools.borrow(KeptMob, room) as KeptMob
	mob.hp = 7
	party.mob = mob
	assert_true(slots.write("pending_party"), "write")
	assert_true(runs.end(), "end")
	room.free()
	await get_tree().process_frame
	# Continue flow: no throwaway run — only pending_slot, then open play scene.
	slots.pending_slot = "pending_party"
	var play := _open(ROOM)
	assert_eq(slots.pending_slot, "", "pending cleared")
	assert_true(runs.is_open(), "scene-enter load started a run")
	var loaded := box.resolve(KeptParty) as KeptParty
	assert_not_null(loaded.mob, "mob restored under the new scene")
	assert_eq(loaded.mob.hp, 7, "pooled fields restored")
	assert_eq(loaded.ready_hp, 7, "filled before @Ready")
	assert_eq(box.pool_holds(play).size(), 1, "hold under play scene")


func test_scene_open_without_pending_does_not_start_a_run() -> void:
	assert_false(runs.is_open(), "cold")
	_open(ROOM)
	assert_false(runs.is_open(), "no pending means no load")


func _open(path: String) -> Node:
	var packed := load(path) as PackedScene
	var room := packed.instantiate() as Node
	add_child(room)
	_handle_noise()
	return room


func _free_rooms() -> void:
	for child in get_children():
		if child is Node and String((child as Node).scene_file_path) != "":
			(child as Node).free()


func _wipe_root(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir():
			dir.remove(name)
		name = dir.get_next()
	DirAccess.remove_absolute(path)


func _handle_noise() -> void:
	for err in get_errors():
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("NoSuchAddon") != -1 or text.find("not a global class") != -1:
			err.handled = true
