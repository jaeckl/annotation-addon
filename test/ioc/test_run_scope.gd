extends GutTest

const ROOM := "res://test/ioc/async_room.tscn"
const VISIT := "res://test/ioc/visit_room.tscn"

var box: IOCContainer
var runs: Runs
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
		if text.find("RunScope") != -1:
			scan_errors.append(text)
		err.handled = true
	runs = box.resolve(Runs) as Runs


func after_each() -> void:
	if box != null:
		box.shutdown()
	box = null
	runs = null
	_free_rooms()
	# An ended run node is freed after the frame.
	await get_tree().process_frame


func test_a_run_product_needs_an_open_run() -> void:
	assert_false(runs.is_open(), "no run is open after discovery")
	assert_null(box.resolve(RunWallet), "nothing is built")
	assert_engine_error("RunWallet is run scoped and no run is open.")


func test_one_instance_lives_for_one_run() -> void:
	assert_true(runs.start(), "the run opens")
	assert_true(runs.is_open(), "the run is open")
	var wallet := box.resolve(RunWallet) as RunWallet
	assert_eq(box.resolve(RunWallet), wallet, "a second resolve returns the same instance")
	wallet.gold = 5
	assert_true(runs.restart(), "restart ends the run and opens another")
	var fresh := box.resolve(RunWallet) as RunWallet
	assert_ne(fresh, wallet, "the new run builds a new instance")
	assert_eq(fresh.gold, 100, "the new instance starts from its defaults")


func test_restart_opens_a_run_when_none_is_open() -> void:
	assert_true(runs.restart(), "restart without a run only starts one")
	assert_true(runs.is_open(), "the run is open")


func test_end_destroys_in_reverse_publish_order() -> void:
	runs.start()
	var board := box.resolve(RunBoard) as RunBoard
	assert_true(runs.end(), "the run ends")
	assert_false(runs.is_open(), "no run is open")
	assert_eq(board.log.lines, ["ready:wallet", "ready:board", "down:board", "down:wallet"], "a dependent is destroyed before its dependency")
	assert_null(box.resolve(RunWallet), "a run product is gone after the run")
	assert_engine_error("RunWallet is run scoped and no run is open.")


func test_shutdown_destroys_the_run_before_the_app() -> void:
	var peeker := box.resolve(RunPeeker) as RunPeeker
	runs.start()
	box.resolve(RunBoard)
	box.shutdown()
	assert_eq(peeker.log.lines, ["ready:wallet", "ready:board", "down:board", "down:wallet", "down:peeker"], "run products are destroyed first")
	assert_eq(peeker.gold_at_end, -1, "shutdown does not publish RunEnding")


func test_start_and_end_report_the_wrong_state() -> void:
	assert_false(runs.end(), "there is nothing to end")
	assert_engine_error("no run is open.")
	runs.start()
	assert_false(runs.start(), "a second start is refused")
	assert_engine_error("a run is already open. Use restart.")


func test_an_app_product_cannot_inject_a_run_product() -> void:
	runs.start()
	box.resolve(RunWallet)
	assert_null(box.resolve(RunKeeper), "the app product is not built")
	assert_engine_error("RunKeeper outlives the run and cannot hold RunWallet.")
	assert_engine_error("missing field wallet on RunKeeper.")


func test_an_app_product_reads_the_run_at_call_time() -> void:
	var peeker := box.resolve(RunPeeker) as RunPeeker
	runs.start()
	assert_eq(peeker.gold(), 100, "Runs.resolve returns the run product")
	(box.resolve(RunWallet) as RunWallet).gold = 7
	assert_eq(peeker.gold(), 7, "it is the same instance")
	runs.restart()
	assert_eq(peeker.gold(), 100, "after a restart it is the new instance")
	assert_null(runs.resolve(RunLog), "an app product is not a run product")
	assert_engine_error("no run product for RunLog")


func test_a_run_product_cannot_inject_a_scene_product() -> void:
	var room := _open(ROOM)
	runs.start()
	assert_null(box.resolve(RunGrabber, [], room), "the run product is not built")
	assert_engine_error("RunGrabber is run scoped and cannot hold scene product LifeScene.")
	assert_engine_error("missing field scene on RunGrabber.")


func test_a_run_product_survives_a_scene_change() -> void:
	runs.start()
	var room := _open(ROOM)
	var first := box.resolve(RunSceneTick, [], room) as RunSceneTick
	first.wallet.gold = 42
	room.free()
	_handle_scene_noise()
	var next := _open(VISIT)
	var second := box.resolve(RunSceneTick, [], next) as RunSceneTick
	assert_ne(second, first, "the scene product is rebuilt with the scene")
	assert_eq(second.wallet, first.wallet, "both scenes share the run product")
	assert_eq(second.wallet.gold, 42, "the state crossed the scene change")


func test_a_scene_node_is_filled_from_the_run() -> void:
	runs.start()
	var hud := RunHud.new()
	add_child_autofree(hud)
	assert_eq(hud.wallet, box.resolve(RunWallet), "a node that is not a product receives the run product")
	assert_eq(hud.purses, [box.resolve(RunPurse)], "a typed array receives run products too")


func test_a_pooled_instance_is_filled_from_the_run() -> void:
	var pools := box.resolve(InstancePools) as InstancePools
	var room := _open(ROOM)
	runs.start()
	var shot := pools.borrow(RunShot, room) as RunShot
	assert_eq(shot.wallet, box.resolve(RunWallet), "a pooled instance leaves with its scene, so it may hold the run product")


func test_an_app_product_cannot_inject_a_list_of_run_products() -> void:
	runs.start()
	assert_null(box.resolve(RunListKeeper), "the app product is not built")
	assert_engine_error("RunListKeeper outlives the run and cannot hold RunConfig.purse.")
	assert_engine_error("missing field purses on RunListKeeper.")


func test_a_factory_method_is_run_scoped() -> void:
	runs.start()
	var purse := box.resolve(RunPurse) as RunPurse
	assert_not_null(purse.log, "the factory arguments are injected")
	assert_eq(box.resolve(RunPurse), purse, "the run keeps one instance")
	runs.restart()
	assert_ne(box.resolve(RunPurse), purse, "the next run calls the factory again")


func test_run_events_reach_every_scope() -> void:
	var peeker := box.resolve(RunPeeker) as RunPeeker
	var room := _open(ROOM)
	runs.start()
	var scene := box.resolve(RunSceneTick, [], room) as RunSceneTick
	var ticker := box.resolve(RunTicker) as RunTicker
	assert_eq(peeker.started, 1, "an app listener hears RunStarted")
	assert_eq(scene.started, 0, "a scene product built after the start missed it")
	(box.resolve(RunWallet) as RunWallet).gold = 9
	runs.end()
	assert_eq(peeker.gold_at_end, 9, "run products are still there while RunEnding is published")
	assert_eq(ticker.ending, 1, "a run listener hears RunEnding")
	runs.start()
	assert_eq(peeker.started, 2, "the next run starts")
	assert_eq(scene.started, 1, "a listener of an open scene hears RunStarted")


func test_a_start_listener_can_build_a_run_product() -> void:
	var peeker := box.resolve(RunPeeker) as RunPeeker
	peeker.warm_up = true
	runs.start()
	var ticker := box.resolve(RunTicker) as RunTicker
	box.run_process(0.1)
	assert_eq(peeker.log.lines, ["tick:run"], "the product built from RunStarted is already ticking")
	assert_not_null(ticker, "it is the run's instance")


func test_end_from_a_run_ending_listener_is_refused() -> void:
	var peeker := box.resolve(RunPeeker) as RunPeeker
	peeker.end_again = true
	runs.start()
	assert_true(runs.end(), "the outer end finishes")
	assert_engine_error("the run is already ending.")
	assert_false(runs.is_open(), "the run is closed once")


func test_the_frame_order_is_app_run_scene() -> void:
	var room := _open(ROOM)
	runs.start()
	box.resolve(RunSceneTick, [], room)
	box.resolve(RunTicker)
	var app := box.resolve(RunAppTick) as RunAppTick
	box.run_process(0.1)
	assert_eq(_starting(app.log.lines, "tick:"), ["tick:app", "tick:run", "tick:scene"], "the scope decides the order, not the publish order")


func test_ticks_listeners_and_schedules_leave_with_the_run() -> void:
	var events := box.resolve(EventPublisher) as EventPublisher
	runs.start()
	var ticker := box.resolve(RunTicker) as RunTicker
	events.publish(RunPing.new())
	box.run_process(0.1)
	box.run_scheduled(0.1)
	box.run_scheduled(0.1)
	box.run_unhandled_input(InputEventKey.new())
	box.run_input_actions()
	assert_eq(ticker.heard, 1, "a run listener hears an app event")
	assert_eq(ticker.log.lines, ["tick:run"], "a run product ticks")
	assert_eq(ticker.beats, 1, "a run product is scheduled")
	assert_eq(ticker.keys, 1, "a run product receives leftover input")
	assert_eq(ticker.polls, 1, "a run product polls an action")
	runs.end()
	events.publish(RunPing.new())
	box.run_process(0.1)
	box.run_scheduled(0.1)
	box.run_scheduled(0.1)
	box.run_unhandled_input(InputEventKey.new())
	box.run_input_actions()
	assert_eq(ticker.heard, 1, "the listener left with the run")
	assert_eq(ticker.log.lines, ["tick:run"], "the tick left with the run")
	assert_eq(ticker.beats, 1, "the schedule left with the run")
	assert_eq(ticker.keys, 1, "the input method left with the run")
	assert_eq(ticker.polls, 1, "the action left with the run")


func test_a_run_product_visits_scenes_until_the_run_ends() -> void:
	_open(ROOM)
	runs.start()
	var ticker := box.resolve(RunTicker) as RunTicker
	assert_eq(_rooms(ticker.visits), ["in:AsyncRoom"], "an open scene is entered when the product is published")
	var visit := _open(VISIT)
	visit.free()
	_handle_scene_noise()
	assert_eq(_rooms(ticker.visits), ["in:AsyncRoom", "in:VisitRoom", "out:VisitRoom"], "later scenes are entered and left")
	runs.end()
	_open(VISIT)
	assert_eq(_rooms(ticker.visits).size(), 3, "the visits stop with the run")


func test_a_node_product_lives_under_the_run_node() -> void:
	runs.start()
	var body := box.resolve(RunBody) as RunBody
	await get_tree().process_frame
	assert_eq(body.get_parent().get_path(), NodePath("/root/IocRuns/IocRun"), "the node is parented under the run node")
	assert_eq(body.wallet_at_ready, box.resolve(RunWallet), "the field is filled before _ready")
	runs.end()
	assert_false(body.is_inside_tree(), "the node leaves the tree when the run ends")
	await get_tree().process_frame
	assert_false(is_instance_valid(body), "the node is freed after the frame")
	assert_false(get_tree().root.has_node("IocRuns/IocRun"), "the run node is gone")


func test_a_node_product_that_never_entered_is_freed() -> void:
	runs.start()
	var body := box.resolve(RunBody) as RunBody
	runs.end()
	await get_tree().process_frame
	assert_false(is_instance_valid(body), "a node still waiting for its parent is freed with the run")


func test_freeing_the_run_node_closes_the_run() -> void:
	runs.start()
	var board := box.resolve(RunBoard) as RunBoard
	get_tree().root.get_node("IocRuns/IocRun").free()
	assert_false(runs.is_open(), "the run cannot continue without its node")
	assert_eq(_starting(board.log.lines, "down:"), ["down:board", "down:wallet"], "the products are still destroyed")
	assert_true(runs.start(), "another run can open")


func test_a_run_product_is_not_built_while_the_run_is_destroyed() -> void:
	runs.start()
	var late := box.resolve(RunLate) as RunLate
	runs.end()
	assert_null(late.found, "nothing is built during @OnDestroy")
	assert_engine_error("the run is ending. RunConfig.purse is not built.")


func test_bad_marks_are_rejected() -> void:
	assert_true(_has("RunBadPooled is @RunScope and @Pooled. A product has one scope."), "a pooled class keeps the pool")
	assert_true(_has("RunBadPlain is @RunScope without @Component."), "the mark needs a product")
	assert_true(_has("RunBadConfig is @RunScope on a configuration. Mark the factory method."), "a configuration is a factory")
	assert_true(_has("RunBadConfig.loose is @RunScope and is not a factory method."), "a plain configuration method is rejected")
	assert_true(_has("RunBadMember.ping is @RunScope and is not a factory method."), "a component method is rejected")
	assert_true(_has("@RunScope on RunBadMember belongs on a class or a factory method."), "a field is rejected")
	assert_true(_has("RunBadScene is @RunScope and waits for a scene. A product has one scope."), "a node condition is another scope")
	assert_true(_has("RunBadAspect is @RunScope and @Aspect. Advice is app scoped."), "an aspect stays in the app")
	assert_true(_has("RunBadHook is a ContainerHook and cannot be @RunScope."), "a hook is needed before any run")


func _has(needle: String) -> bool:
	for text in scan_errors:
		if text.find(needle) != -1:
			return true
	return false


func _starting(lines: Array, prefix: String) -> Array:
	var kept: Array = []
	for line in lines:
		if String(line).begins_with(prefix):
			kept.append(line)
	return kept


## The test runner's own scenes are open too.
func _rooms(lines: Array) -> Array:
	var kept: Array = []
	for line in lines:
		var text := String(line)
		if text.ends_with(":AsyncRoom") or text.ends_with(":VisitRoom"):
			kept.append(text)
	return kept


func _open(path: String) -> Node:
	var packed := load(path) as PackedScene
	var room := packed.instantiate()
	add_child(room)
	_handle_scene_noise()
	return room


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


func _handle_scene_noise() -> void:
	for err in get_errors():
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("NoSuchAddon") != -1 or text.find("not a global class") != -1:
			err.handled = true
