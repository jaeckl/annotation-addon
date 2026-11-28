extends GutTest

var box: IOCContainer
var scan_errors: PackedStringArray = PackedStringArray()
var node: Node


func before_each() -> void:
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	scan_errors = PackedStringArray()
	for err in get_errors():
		scan_errors.append("%s %s" % [err.code, err.rationale])
		err.handled = true


func after_each() -> void:
	if is_instance_valid(node):
		node.free()
	node = null
	if box != null:
		box.shutdown()
	box = null


func test_before_around_and_after_wrap_the_call() -> void:
	var log := box.resolve(CallLog) as CallLog
	var desk := box.resolve(WovenDesk) as WovenDesk
	assert_eq(desk.ping(), "pong", "the method return is kept")
	assert_eq(log.calls, ["before:ping:[]", "around:ping", "after:ping:pong"], "before, around, then after")
	log.calls.clear()
	assert_eq(desk.add(), 2, "the default argument is kept")
	assert_eq(log.calls, ["before:add:[2]", "around:add", "after:add:2"], "the default is visible to the advice")
	log.calls.clear()
	assert_eq(desk.plain(), "plain", "a method without the mark is unchanged")
	assert_eq(log.calls.size(), 0, "the plain method is not advised")
	assert_eq(desk.plain_ran, 1, "the plain method ran once")


func test_around_can_replace_arguments() -> void:
	var desk := box.resolve(AdjustedDesk) as AdjustedDesk
	assert_eq(desk.add(5), 6, "proceed can replace the arguments")


func test_skipping_proceed_skips_the_method_and_after_still_runs() -> void:
	var log := box.resolve(SkipLog) as SkipLog
	var desk := box.resolve(SkippedDesk) as SkippedDesk
	assert_eq(desk.ping(), "skipped", "the around return replaces the method")
	assert_eq(desk.ran, 0, "the method did not run")
	assert_true(log.ran_after, "after runs when proceed is skipped")
	assert_eq(log.result, "skipped", "after sees the chain result")


func test_befores_run_in_source_order() -> void:
	var log := box.resolve(OrderLog) as OrderLog
	var desk := box.resolve(TimedDesk) as TimedDesk
	assert_eq(desk.ping(), "pong", "the method still returns")
	assert_eq(log.log, ["first", "second"], "source order is the advice order")


func test_arounds_nest_in_source_order() -> void:
	var log := box.resolve(NestLog) as NestLog
	var desk := box.resolve(NestedDesk) as NestedDesk
	assert_eq(desk.ping(), "pong", "the nested chain returns the method value")
	assert_eq(desk.ran, 1, "the method ran once")
	assert_eq(log.log, ["outer", "inner", "inner-done", "outer-done"], "the first around wraps the second")


func test_self_call_is_advised_and_super_is_not() -> void:
	var log := box.resolve(CallLog) as CallLog
	var desk := box.resolve(ChildDesk) as ChildDesk
	assert_eq(desk.outer(), "outer", "the outer method returns")
	assert_eq(desk.outer_count, 1, "the outer method ran")
	assert_eq(desk.inner_count, 1, "the self call reached the parent method")
	assert_eq(log.calls, [
		"before:outer:[]",
		"around:outer",
		"before:inner:[]",
		"around:inner",
		"after:inner:inner",
		"after:outer:outer",
	], "the self call is advised too")
	log.calls.clear()
	assert_eq(desk.jump(), "inner", "super returns the parent value")
	assert_eq(desk.inner_count, 2, "super reached the parent method")
	assert_eq(log.calls.size(), 0, "super is not advised")


func test_qualifier_and_type_still_select_the_woven_instance() -> void:
	var mark := _qualifier("woven")
	var desk := box.resolve(DeskBase, [mark]) as WovenDesk
	assert_not_null(desk, "the qualifier still selects the product")
	assert_true(desk is WovenDesk, "the instance is the original class")
	assert_false(desk.get_script() == WovenDesk, "the live script is the proxy")
	assert_eq(desk.get_script().get_base_script(), WovenDesk, "the proxy extends the component")
	var wrong := _qualifier("nope")
	assert_null(box.resolve(DeskBase, [wrong]), "a different qualifier does not match")
	assert_push_error("no component")


func test_aspect_is_not_woven() -> void:
	var log := box.resolve(CallLog) as CallLog
	assert_eq(log.get_script(), CallLog, "an aspect keeps its own script")
	assert_eq(log.own(), "aspect", "the aspect method still runs")
	assert_eq(log.calls.size(), 0, "the aspect method is not advised")


func test_factory_product_is_not_woven() -> void:
	var log := box.resolve(CallLog) as CallLog
	var desk := box.resolve(FactoryDesk) as FactoryDesk
	assert_eq(desk.ping(), "pong", "the factory product still runs")
	assert_eq(desk.ran, 1, "the method ran")
	assert_eq(desk.get_script(), FactoryDesk, "the factory product keeps its script")
	assert_eq(log.calls.size(), 0, "a factory product is not advised")


func test_listener_on_a_woven_component_still_receives_the_event() -> void:
	var log := box.resolve(CallLog) as CallLog
	var listener := box.resolve(LoggedListener) as LoggedListener
	var events := box.resolve(EventPublisher) as EventPublisher
	events.publish(AopPing.new(4))
	assert_eq(listener.seen, 4, "the listener still runs")
	assert_true(String(log.calls[0]).begins_with("before:on_ping:"), "advice wraps the listener")


func test_woven_node_is_injected_once() -> void:
	node = box.resolve(WovenNode)
	var woven := node as WovenNode
	assert_eq(woven.hits, 1, "the field is set when the node is constructed")
	assert_not_null(woven.held, "the dependency is the component")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(woven.hits, 1, "entering the tree does not inject again")


func test_advice_marks_must_sit_on_an_aspect_method() -> void:
	assert_true(_scan_has("AdviceOnPlain.ping is @Before without @Aspect"), "advice needs an aspect")
	assert_true(_scan_has("AdviceNoComponent is @Aspect without @Component"), "an aspect is a component")
	assert_true(_scan_has("AdviceConfig is @Aspect without @Component"), "a configuration is not a component")
	assert_true(_scan_has("AdviceConfig is @Aspect on a configuration"), "a configuration is not an aspect")
	assert_true(_scan_has("@Before on AdviceBadShape belongs on a method"), "a field cannot advise")
	assert_true(_scan_has("AdviceBadShape.wrong_pointcut pointcut must be an annotation"), "the pointcut is an annotation class")
	assert_true(_scan_has("AdviceBadShape.no_args must take one JoinPoint"), "before takes one join point")
	assert_true(_scan_has("AdviceBadShape.two must take one JoinPoint"), "extra arguments are rejected")


func test_constructor_and_static_methods_are_not_advised() -> void:
	var created := box.resolve(AdviceInit)
	assert_not_null(created, "the component is still constructed")
	assert_push_error("AdviceInit._init cannot be advised")
	assert_push_error("AdviceInit.stat is static and cannot be advised")
	assert_push_error("AdviceInit.stat is static and cannot be @Logged")


func _qualifier(text: String) -> Qualifier:
	return AnnotationUtils.instantiate_annotation({
		"name": "Qualifier",
		"values": {"value": text},
	}) as Qualifier


func _scan_has(text: String) -> bool:
	for line in scan_errors:
		if line.find(text) != -1:
			return true
	return false
