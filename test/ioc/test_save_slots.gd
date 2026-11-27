extends GutTest

const ROOM := "res://test/ioc/async_room.tscn"

var box: IOCContainer
var runs: Runs
var slots: SaveSlots
var pools: InstancePools
var _slot_root: String = ""


func before_each() -> void:
	_slot_root = "user://save_slots_%s" % Time.get_ticks_usec()
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	_handle_discover_noise()
	runs = box.resolve(Runs) as Runs
	slots = box.resolve(SaveSlots) as SaveSlots
	pools = box.resolve(InstancePools) as InstancePools
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


func test_write_and_load_roundtrip_a_built_persist_product() -> void:
	assert_true(runs.start(), "run opens")
	var stash := box.resolve(KeptStash) as KeptStash
	stash.coins = 12
	stash.note = "hi"
	assert_true(slots.write("slot1"), "write")
	assert_true(slots.has("slot1"), "has")
	assert_true(slots.load("slot1"), "load")
	var loaded := box.resolve(KeptStash) as KeptStash
	assert_ne(loaded, stash, "a new run product")
	assert_eq(loaded.coins, 12, "coins restored")
	assert_eq(loaded.note, "hi", "note restored")
	assert_eq(loaded.ready_coins, 12, "filled before @Ready")


func test_write_skips_unresolved_persist_products() -> void:
	assert_true(runs.start(), "run opens")
	var stash := box.resolve(KeptStash) as KeptStash
	stash.coins = 2
	assert_true(slots.write("only_stash"), "write")
	assert_true(slots.load("only_stash"), "load")
	var vault := box.resolve(KeptVault) as KeptVault
	assert_eq(vault.coins, 0, "unresolved product was not in the slot")
	assert_eq((box.resolve(KeptStash) as KeptStash).coins, 2, "stash restored")


func test_load_rejects_a_bad_slot_without_ending_the_run() -> void:
	assert_true(runs.start(), "run opens")
	var stash := box.resolve(KeptStash) as KeptStash
	stash.coins = 9
	assert_true(slots.write("good"), "write")
	var path := slots.root.path_join("bad.zip")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not-a-zip")
	file.close()
	assert_false(slots.load("bad"), "bad slot refused")
	assert_push_error("Save:")
	assert_true(runs.is_open(), "the run stayed open")
	assert_eq((box.resolve(KeptStash) as KeptStash).coins, 9, "state untouched")


func test_an_unreadable_persist_entry_keeps_the_run() -> void:
	assert_true(runs.start(), "run opens")
	var stash := box.resolve(KeptStash) as KeptStash
	stash.coins = 4
	assert_true(slots.write("ok"), "write")
	var sink := FileSink.new()
	sink.path = slots.root.path_join("broken.zip")
	var bundle := ZipBundle.new()
	bundle.sink = sink
	bundle.add("header", slots.mapper.codec.write({"products": ["KeptStash"]}))
	bundle.add("KeptStash", JSON.stringify({"_type": "KeptStash", "nope": 1}).to_utf8_buffer())
	bundle.finish()
	assert_false(slots.load("broken"), "unreadable entry refused")
	assert_push_error("Serialize:")
	assert_true(runs.is_open(), "the run stayed open")
	assert_eq((box.resolve(KeptStash) as KeptStash).coins, 4, "state untouched")


func test_a_bad_slot_name_is_rejected() -> void:
	assert_true(runs.start(), "run opens")
	box.resolve(KeptStash)
	assert_false(slots.write("bad name"), "spaces are refused")
	assert_push_error("slot name")
	assert_false(slots.write("../x"), "path climb is refused")
	assert_push_error("slot name")
	assert_false(slots.has("bad name"), "has rejects too")


func test_two_products_of_the_same_class_fail_write() -> void:
	assert_true(runs.start(), "run opens")
	var alpha_q := Qualifier.new()
	alpha_q.value = "alpha"
	var beta_q := Qualifier.new()
	beta_q.value = "beta"
	assert_not_null(box.resolve(KeptTwin, [alpha_q]), "alpha built")
	assert_not_null(box.resolve(KeptTwin, [beta_q]), "beta built")
	assert_false(slots.write("twins"), "duplicate class fails")
	assert_push_error("two products of class KeptTwin")


func test_has_list_and_erase() -> void:
	assert_true(runs.start(), "run opens")
	box.resolve(KeptStash)
	assert_true(slots.write("a"), "write a")
	assert_true(slots.write("b"), "write b")
	var names := slots.list()
	assert_eq(names.size(), 2, "two slots")
	assert_eq(names[0], "a", "sorted")
	assert_eq(names[1], "b", "sorted")
	assert_true(slots.erase("a"), "erase a")
	assert_false(slots.has("a"), "a is gone")
	assert_eq(slots.list(), PackedStringArray(["b"]), "b remains")
	assert_false(slots.erase("a"), "already gone")
	assert_push_error("missing")


func test_load_ends_an_open_run_and_starts_another() -> void:
	assert_true(runs.start(), "run opens")
	var first := box.resolve(KeptStash) as KeptStash
	first.coins = 3
	assert_true(slots.write("mid"), "write")
	first.coins = 99
	assert_true(slots.load("mid"), "load")
	assert_true(runs.is_open(), "a run is open")
	var second := box.resolve(KeptStash) as KeptStash
	assert_ne(second, first, "new instance")
	assert_eq(second.coins, 3, "restored from the slot")


func test_load_starts_a_run_when_none_is_open() -> void:
	assert_true(runs.start(), "run opens")
	var stash := box.resolve(KeptStash) as KeptStash
	stash.coins = 8
	assert_true(slots.write("cold"), "write")
	assert_true(runs.end(), "end")
	assert_false(runs.is_open(), "closed")
	assert_true(slots.load("cold"), "load without an open run")
	assert_true(runs.is_open(), "load started a run")
	assert_eq((box.resolve(KeptStash) as KeptStash).coins, 8, "restored")


func test_write_needs_an_open_run() -> void:
	assert_false(slots.write("x"), "no run")
	assert_push_error("no run is open")


func test_pooled_bodies_are_released_and_borrowed_on_load() -> void:
	var room := _open(ROOM)
	slots.body_parent = room
	assert_true(runs.start(), "run opens")
	var party := box.resolve(KeptParty) as KeptParty
	var mob := pools.borrow(KeptMob, room) as KeptMob
	mob.hp = 7
	party.mob = mob
	assert_true(slots.write("party"), "write")
	assert_eq(box.pool_holds(room).size(), 1, "one live hold")
	assert_true(slots.load("party"), "load")
	var loaded := box.resolve(KeptParty) as KeptParty
	assert_not_null(loaded.mob, "mob restored")
	assert_eq(loaded.mob.hp, 7, "pooled fields restored")
	assert_eq(loaded.ready_hp, 7, "filled before @Ready")
	assert_eq(box.pool_holds(room).size(), 1, "one live hold after load")


func test_pooled_bodies_fall_back_to_the_current_scene() -> void:
	var room := _open(ROOM)
	var previous := get_tree().current_scene
	get_tree().current_scene = room
	slots.body_parent = null
	assert_true(runs.start(), "run opens")
	var party := box.resolve(KeptParty) as KeptParty
	var mob := pools.borrow(KeptMob, room) as KeptMob
	mob.hp = 5
	party.mob = mob
	assert_true(slots.write("party2"), "write")
	assert_true(slots.load("party2"), "load with no body_parent")
	var loaded := box.resolve(KeptParty) as KeptParty
	assert_eq(loaded.mob.hp, 5, "borrowed under the current scene")
	get_tree().current_scene = previous


func test_blank_save_writes_an_empty_header() -> void:
	assert_true(runs.start(), "run opens")
	assert_true(slots.write("empty"), "blank write")
	assert_true(slots.load("empty"), "blank load")
	assert_true(runs.is_open(), "run open after blank load")


func _open(path: String) -> Node:
	var packed := load(path) as PackedScene
	var room := packed.instantiate() as Node
	add_child(room)
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
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _handle_discover_noise() -> void:
	for err in get_errors():
		if err.handled:
			continue
		err.handled = true
