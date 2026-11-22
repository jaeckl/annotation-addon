extends GutTest

var box: IOCContainer
var gate: AsyncLatch
var events: EventPublisher
var scan_errors: PackedStringArray = PackedStringArray()


func before_each() -> void:
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	scan_errors = PackedStringArray()
	for err in get_errors():
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("Async") != -1:
			scan_errors.append(text)
		err.handled = true
	gate = box.resolve(AsyncLatch) as AsyncLatch
	events = box.resolve(EventPublisher) as EventPublisher


func after_each() -> void:
	if box != null:
		box.shutdown()
	box = null
	gate = null
	events = null


func test_async_returns_after_publish_and_then_publishes_the_event() -> void:
	var bridge := box.resolve(AsyncPaceBridge) as AsyncPaceBridge
	var desk := box.resolve(PaceDesk) as PaceDesk
	var mark := box.resolve(SyncPaceMark) as SyncPaceMark
	events.publish(PaceChanged.new(5))
	assert_eq(bridge.started, 1, "the listener started before publish returned")
	assert_eq(mark.seen, 1, "a sync listener still runs before publish returns")
	assert_eq(desk.noted.size(), 0, "the returned event waits for the await")
	gate.opened.emit()
	assert_eq(desk.noted.size(), 1, "the returned event is published when the method finishes")
	assert_eq(desk.noted[0].current, 5, "the returned event keeps the value")


func test_async_without_await_publishes_in_the_same_call() -> void:
	box.resolve(ImmediateAsyncBridge)
	var desk := box.resolve(PaceDesk) as PaceDesk
	events.publish(PaceChanged.new(2))
	assert_eq(desk.noted.size(), 1, "a returned event is published before publish returns")
	assert_eq(desk.noted[0].current, 2, "the value is kept")


func test_second_await_holds_the_event_until_the_method_finishes() -> void:
	box.resolve(AsyncDoubleBridge)
	var desk := box.resolve(PaceDesk) as PaceDesk
	events.publish(PaceChanged.new(7))
	gate.opened.emit()
	assert_eq(desk.noted.size(), 0, "the first await does not publish the return")
	gate.next.emit()
	assert_eq(desk.noted.size(), 1, "the return is published after the last await")
	assert_eq(desk.noted[0].current, 7, "the value is kept")


func test_async_chain_publishes_each_returned_event() -> void:
	box.resolve(AsyncPaceBridge)
	box.resolve(AsyncNotedBridge)
	var noted := box.resolve(PaceDesk) as PaceDesk
	var done := box.resolve(PaceDoneDesk) as PaceDoneDesk
	events.publish(PaceChanged.new(6))
	assert_eq(noted.noted.size(), 0, "the first return waits")
	gate.opened.emit()
	assert_eq(noted.noted.size(), 1, "the first return is published")
	assert_eq(done.done.size(), 0, "the second listener waits on its own signal")
	gate.next.emit()
	assert_eq(done.done.size(), 1, "the second return is published")
	assert_eq(done.done[0].current, 6, "the value crosses both listeners")


func test_same_event_class_stays_blocked_until_the_async_listener_finishes() -> void:
	var bridge := box.resolve(AsyncPaceBridge) as AsyncPaceBridge
	var mark := box.resolve(SyncPaceMark) as SyncPaceMark
	var desk := box.resolve(PaceDesk) as PaceDesk
	events.publish(PaceChanged.new(1))
	events.publish(PaceChanged.new(9))
	assert_engine_error("already in progress")
	assert_eq(bridge.started, 1, "the second publish does not call the listener again")
	assert_eq(mark.seen, 1, "the second publish does not call the sync listener")
	gate.opened.emit()
	assert_eq(desk.noted.size(), 1, "only the first event is published onward")
	assert_eq(desk.noted[0].current, 1, "the blocked publish is dropped")
	events.publish(PaceChanged.new(4))
	assert_eq(bridge.started, 2, "a later publish runs after the listener finishes")


func test_async_return_of_the_same_event_class_is_refused() -> void:
	var desk := box.resolve(HealthDesk) as HealthDesk
	box.resolve(AsyncLoopHealth)
	events.publish(HealthChanged.new(4))
	assert_eq(desk.health.size(), 1, "the original event is delivered")
	gate.opened.emit()
	assert_engine_error("publish of HealthChanged is already in progress")
	assert_eq(desk.health.size(), 1, "the returned event is not delivered")


func test_await_without_async_does_not_publish_the_return() -> void:
	var bridge := box.resolve(BareAwaitBridge) as BareAwaitBridge
	var desk := box.resolve(PaceDesk) as PaceDesk
	events.publish(PaceChanged.new(5))
	assert_engine_error("returned Object, not an Event")
	assert_eq(bridge.started, 1, "the method still starts")
	assert_eq(desk.noted.size(), 0, "the function state is not published")
	gate.opened.emit()
	assert_eq(bridge.finished, 1, "the method still finishes")
	assert_eq(desk.noted.size(), 0, "the later return is dropped")


func test_async_non_event_return_is_an_error() -> void:
	box.resolve(AsyncBadReturn)
	var desk := box.resolve(PaceDesk) as PaceDesk
	events.publish(PaceChanged.new(5))
	gate.opened.emit()
	assert_engine_error("returned int, not an Event")
	assert_eq(desk.noted.size(), 0, "the int is not published")


func test_async_null_return_publishes_nothing() -> void:
	var silent := box.resolve(AsyncSilent) as AsyncSilent
	var desk := box.resolve(PaceDesk) as PaceDesk
	events.publish(PaceChanged.new(5))
	gate.opened.emit()
	assert_eq(silent.finished, 1, "the method finished")
	assert_eq(desk.noted.size(), 0, "a null return publishes nothing")


func test_async_scene_return_stays_on_the_publishing_scene() -> void:
	var packed := load("res://test/ioc/async_room.tscn") as PackedScene
	var left := packed.instantiate()
	var right := packed.instantiate()
	add_child(left)
	add_child(right)
	_handle_scene_noise()
	var left_bridge := box.resolve(SceneAsyncBridge, [], left) as SceneAsyncBridge
	var right_bridge := box.resolve(SceneAsyncBridge, [], right) as SceneAsyncBridge
	var desk := box.resolve(PaceDesk) as PaceDesk
	events.publish(PaceChanged.new(8), left)
	assert_eq(left_bridge.started, 1, "the publishing scene hears the event")
	assert_eq(right_bridge.started, 0, "the other scene does not")
	assert_eq(desk.noted.size(), 0, "the return waits")
	gate.opened.emit()
	assert_eq(left_bridge.noted, 1, "the returned event stays on the publishing scene")
	assert_eq(right_bridge.noted, 0, "the other scene does not hear the return")
	assert_eq(right_bridge.started, 0, "the other scene still has not heard the first event")
	assert_eq(desk.noted.size(), 1, "an app listener hears the returned event")
	left.free()
	right.free()


func test_leaving_scene_drops_the_async_return_and_releases_the_event() -> void:
	var packed := load("res://test/ioc/async_room.tscn") as PackedScene
	var room := packed.instantiate()
	add_child(room)
	_handle_scene_noise()
	var bridge := box.resolve(SceneAsyncBridge, [], room) as SceneAsyncBridge
	var desk := box.resolve(PaceDesk) as PaceDesk
	events.publish(PaceChanged.new(1), room)
	events.publish(PaceChanged.new(2), room)
	assert_engine_error("already in progress")
	assert_eq(bridge.started, 1, "only the first publish started the listener")
	room.free()
	_handle_scene_noise()
	gate.opened.emit()
	assert_eq(desk.noted.size(), 0, "a scene that has left does not publish the return")
	events.publish(PaceChanged.new(3))
	assert_false(_has_fresh("already in progress"), "the event class can be published again")


func test_async_mark_requires_an_event_listener() -> void:
	assert_true(_scan_has("AsyncOnField"), "a field mark is rejected")
	assert_true(_scan_has("AsyncMarkedClass"), "a class mark is rejected")
	assert_true(_scan_has("belongs on a method"), "a mark that is not a method says so")
	assert_true(_scan_has("AsyncPlainMethod.ping is @Async without @EventListener"), "a plain method is rejected")
	assert_true(_scan_has("AsyncPlainConfig.ping is @Async without @EventListener"), "a configuration method is rejected")


func _scan_has(text: String) -> bool:
	for line in scan_errors:
		if line.find(text) != -1:
			return true
	return false


func _handle_scene_noise() -> void:
	for err in get_errors():
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("NoSuchAddon") != -1 or text.find("not a global class") != -1:
			err.handled = true


func _has_fresh(text: String) -> bool:
	var found := false
	for err in get_errors():
		if err.handled:
			continue
		if err.contains_text(text):
			found = true
		err.handled = true
	return found
