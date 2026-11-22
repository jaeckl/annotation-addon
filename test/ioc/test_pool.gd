extends GutTest

var box: IOCContainer
var pooled_errors: PackedStringArray = PackedStringArray()


func before_each() -> void:
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	pooled_errors = PackedStringArray()
	for err in get_errors():
		if err.handled:
			continue
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("Pooled") != -1 or text.find("OnRelease") != -1 or text.find("pool limit") != -1 or text.find("reset a pool") != -1 or text.find("must take nothing") != -1:
			pooled_errors.append(text)
		err.handled = true


func after_each() -> void:
	if box != null:
		box.shutdown()
	box = null
	for child in get_tree().root.get_children():
		if child.name == "AsyncRoom" or child.name == "Loose" or child is PoolBolt or child is PoolReleaseWait:
			child.free()


func test_borrow_builds_once_and_recycles() -> void:
	var room := _room()
	var pools := box.resolve(InstancePools) as InstancePools
	var bolt := pools.borrow(PoolBolt, room) as PoolBolt
	var id := bolt.get_instance_id()
	assert_eq(bolt.wakes, 1, "ready runs on the first entry")
	assert_eq(bolt.binds, 1, "inject runs once")
	assert_eq(bolt.pools, pools, "the bolt receives the lender")
	assert_not_null(bolt.clock, "the clock is injected")
	assert_eq(bolt.get_parent(), room, "the caller is the parent")
	pools.release(bolt)
	assert_eq(bolt.get_parent().name, "IocPool", "release parks the node")
	assert_eq(bolt.get_parent().process_mode, Node.PROCESS_MODE_DISABLED, "the park does not process")
	assert_false(bolt.visible, "a parked node is hidden")
	assert_eq(bolt.process_mode, Node.PROCESS_MODE_DISABLED, "a parked node does not process")
	var again := pools.borrow(PoolBolt, room) as PoolBolt
	assert_eq(again.get_instance_id(), id, "the same node comes back")
	assert_eq(again.wakes, 1, "ready does not run again")
	assert_eq(again.binds, 1, "inject does not run again")
	assert_eq(again.get_parent(), room, "borrow reparents to the caller")
	assert_true(again.visible, "a borrowed node is shown")
	assert_eq(again.process_mode, Node.PROCESS_MODE_INHERIT, "a borrowed node processes with its parent")


func test_two_borrows_are_two_instances() -> void:
	var room := _room()
	var pools := box.resolve(InstancePools) as InstancePools
	var first := pools.borrow(PoolBolt, room) as PoolBolt
	var second := pools.borrow(PoolBolt, room) as PoolBolt
	assert_ne(first.get_instance_id(), second.get_instance_id(), "each live borrow is its own node")


func test_a_refcounted_waits_in_the_list() -> void:
	var room := _room()
	var pools := box.resolve(InstancePools) as InstancePools
	var spark := pools.borrow(PoolSpark, room) as PoolSpark
	spark.token = 4
	pools.release(spark)
	var again := pools.borrow(PoolSpark, room) as PoolSpark
	assert_eq(again, spark, "the same object comes back")
	assert_eq(again.token, 4, "release keeps the fields the caller wrote")


func test_resolve_refuses_a_pooled_class() -> void:
	assert_null(box.resolve(PoolBolt), "resolve does not hand out a pooled class")
	assert_engine_error("PoolBolt is pooled. Borrow it.")


func test_borrow_refuses_a_normal_component() -> void:
	var room := _room()
	var pools := box.resolve(InstancePools) as InstancePools
	assert_null(pools.borrow(PoolMethod, room), "a normal component is not a pool")
	assert_engine_error("PoolMethod is not pooled.")


func test_release_of_a_stranger_is_rejected() -> void:
	var pools := box.resolve(InstancePools) as InstancePools
	pools.release(PoolSpark.new())
	assert_engine_error("PoolSpark is not borrowed.")


func test_a_second_release_is_rejected() -> void:
	var room := _room()
	var pools := box.resolve(InstancePools) as InstancePools
	var spark := pools.borrow(PoolSpark, room)
	pools.release(spark)
	pools.release(spark)
	assert_engine_error("PoolSpark is not borrowed.")


func test_borrow_needs_a_parent_and_a_scene() -> void:
	var pools := box.resolve(InstancePools) as InstancePools
	assert_null(pools.borrow(PoolBolt, null), "a parent is required")
	assert_engine_error("borrow needs a parent.")
	var loose := Node.new()
	loose.name = "Loose"
	get_tree().root.add_child(loose)
	assert_null(pools.borrow(PoolBolt, loose), "the parent must belong to a scene")
	assert_engine_error("borrow needs a scene.")


func test_a_scene_node_with_the_pooled_script_is_rejected() -> void:
	var stray := PoolBolt.new()
	get_tree().root.add_child(stray)
	assert_engine_error("PoolBolt is in a scene and is also @Pooled.")


func test_queue_free_drops_the_id() -> void:
	var room := _room()
	var pools := box.resolve(InstancePools) as InstancePools
	var bolt := pools.borrow(PoolBolt, room) as PoolBolt
	var id := bolt.get_instance_id()
	bolt.queue_free()
	await get_tree().process_frame
	var again := pools.borrow(PoolBolt, room) as PoolBolt
	assert_ne(again.get_instance_id(), id, "a freed node is not borrowed again")
	assert_eq(again.wakes, 1, "the replacement is a new node")


func test_the_scene_drops_a_parked_instance() -> void:
	var room := _room()
	var pools := box.resolve(InstancePools) as InstancePools
	var bolt := pools.borrow(PoolBolt, room) as PoolBolt
	var id := bolt.get_instance_id()
	pools.release(bolt)
	room.free()
	_handle_scene_noise()
	var again_room := _room()
	var again := pools.borrow(PoolBolt, again_room) as PoolBolt
	assert_ne(again.get_instance_id(), id, "the next scene builds a new node")
	assert_eq(again.wakes, 1, "the new node is ready once")


func test_pooled_without_a_component_is_rejected() -> void:
	assert_true(_has("PoolPlain is @Pooled without @Component."), "a class mark needs @Component")


func test_pooled_on_a_method_is_rejected() -> void:
	assert_true(_has("@Pooled on PoolMethod belongs on a class."), "the mark is not a method mark")


func test_pooled_on_a_configuration_is_rejected() -> void:
	assert_true(_has("PoolConfig is @Pooled on a configuration."), "a configuration is not a pool")


func test_a_cap_stops_a_new_borrow() -> void:
	var room := _room()
	var pools := box.resolve(InstancePools) as InstancePools
	var first := pools.borrow(PoolCap, room) as PoolCap
	var second := pools.borrow(PoolCap, room) as PoolCap
	assert_not_null(first, "the first borrow is inside the cap")
	assert_not_null(second, "the second borrow fills the cap")
	assert_null(pools.borrow(PoolCap, room), "a third borrow does not build another instance")
	assert_engine_error("PoolCap is at its limit of 2.")
	pools.release(first)
	var again := pools.borrow(PoolCap, room) as PoolCap
	assert_eq(again, first, "a parked instance is still available at the cap")


func test_release_clears_the_instance() -> void:
	var room := _room()
	var pools := box.resolve(InstancePools) as InstancePools
	var shot := pools.borrow(PoolReset, room) as PoolReset
	shot.token = 5
	pools.release(shot)
	assert_eq(shot.token, 0, "the hook clears the shot")
	assert_eq(shot.clears, 1, "release calls the hook once")
	var again := pools.borrow(PoolReset, room) as PoolReset
	assert_eq(again, shot, "the same object comes back")
	assert_eq(again.clears, 1, "borrow does not call the hook")
	assert_eq(again.token, 0, "the cleared field stays cleared")


func test_an_awaiting_release_is_rejected() -> void:
	var room := _room()
	var pools := box.resolve(InstancePools) as InstancePools
	var shot := pools.borrow(PoolReleaseWait, room)
	pools.release(shot)
	assert_engine_error("PoolReleaseWait.linger cannot await.")
	await get_tree().process_frame


func test_a_negative_limit_is_rejected() -> void:
	assert_true(_has("PoolLimitBad pool limit must be at least 0."), "a negative cap is refused")


func test_on_release_must_take_nothing() -> void:
	assert_true(_has("PoolReleaseBad.clear must take nothing."), "a reset method takes nothing")


func test_a_static_on_release_is_rejected() -> void:
	assert_true(_has("PoolReleaseBad.parked is static and cannot reset a pool."), "a static method has no instance")


func test_on_release_on_a_normal_component_is_rejected() -> void:
	assert_true(_has("PoolReleasePlain.clear is @OnRelease and PoolReleasePlain is not pooled."), "the hook belongs to a pool")


func test_on_release_on_a_class_is_rejected() -> void:
	assert_true(_has("@OnRelease on PoolReleaseClass belongs on a method."), "the hook is a method mark")


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
	for text in pooled_errors:
		if text.find(needle) != -1:
			return true
	return false
