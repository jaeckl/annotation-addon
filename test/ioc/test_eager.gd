extends GutTest

var box: IOCContainer
var runs: Runs
var scan_errors: PackedStringArray = PackedStringArray()


func before_each() -> void:
	EagerApp.booted = false
	ProjectSettings.set_setting("ioc/eager_broken", "")
	ProjectSettings.set_setting("ioc/eager_fixtures", "yes")
	ProjectSettings.set_setting("ioc/default_init", "")
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	scan_errors = PackedStringArray()
	for err in get_errors():
		if err.handled:
			continue
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("Eager") != -1 or text.find("Lazy") != -1:
			scan_errors.append(text)
		err.handled = true
	runs = box.resolve(Runs) as Runs


func after_each() -> void:
	ProjectSettings.set_setting("ioc/eager_broken", "")
	ProjectSettings.set_setting("ioc/eager_fixtures", "")
	ProjectSettings.set_setting("ioc/default_init", "")
	if box != null:
		box.shutdown()
	box = null
	runs = null
	await get_tree().process_frame


func test_an_eager_run_product_is_built_before_run_started() -> void:
	assert_true(runs.start(), "the run opens")
	var tick := box.resolve(EagerTick) as EagerTick
	assert_eq(tick.started, 1, "it heard RunStarted because it was already built")
	box.run_process(0.1)
	assert_ne(tick.log.lines.find("tick:eager"), -1, "it ticks without a bootstrap resolve")


func test_a_lazy_run_product_still_waits() -> void:
	assert_true(runs.start(), "the run opens")
	box.run_process(0.1)
	var log := box.resolve(RunLog) as RunLog
	assert_eq(log.lines.find("tick:plain"), -1, "an unmarked product is not built yet")
	box.resolve(EagerPlain)
	box.run_process(0.1)
	assert_ne(log.lines.find("tick:plain"), -1, "the first resolve builds it")


func test_default_init_eager_builds_unmarked_products() -> void:
	box.shutdown()
	box = IOCContainer.new()
	box.default_init = "eager"
	box.setup(get_tree())
	box.discover()
	for err in get_errors():
		err.handled = true
	runs = box.resolve(Runs) as Runs
	assert_true(runs.start(), "the run opens")
	box.run_process(0.1)
	var log := box.resolve(RunLog) as RunLog
	assert_ne(log.lines.find("tick:plain"), -1, "default eager builds the unmarked product")
	assert_eq(log.lines.find("tick:lazy"), -1, "@Lazy opts out of the default")
	box.resolve(EagerLazyTick)
	box.run_process(0.1)
	assert_ne(log.lines.find("tick:lazy"), -1, "the lazy product still builds on resolve")


func test_default_init_comes_from_the_property_environment() -> void:
	box.shutdown()
	box = null
	ProjectSettings.set_setting("ioc/default_init", "eager")
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	for err in get_errors():
		err.handled = true
	var props := box.resolve(IocProperties) as IocProperties
	assert_eq(props.default_init, "eager", "IocProperties is bound from the environment")
	assert_eq(box.default_init, "eager", "the container copies that value")
	runs = box.resolve(Runs) as Runs
	assert_true(runs.start(), "the run opens")
	box.run_process(0.1)
	assert_ne((box.resolve(RunLog) as RunLog).lines.find("tick:plain"), -1, "cfg-backed default eager builds unmarked products")
	ProjectSettings.set_setting("ioc/default_init", "")


func test_a_bad_default_init_is_rejected() -> void:
	box.shutdown()
	box = null
	ProjectSettings.set_setting("ioc/default_init", "sometimes")
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	assert_push_error("ioc/default_init must be lazy or eager")
	for err in get_errors():
		err.handled = true
	assert_eq(box.default_init, "lazy", "the previous default stays")
	var props := box.resolve(IocProperties) as IocProperties
	assert_eq(props.default_init, "sometimes", "the bound object still shows the raw value")
	ProjectSettings.set_setting("ioc/default_init", "")


func test_an_eager_app_product_is_built_at_discover() -> void:
	assert_true(EagerApp.booted, "discover built the eager app product")


func test_an_eager_factory_product_is_built_at_start() -> void:
	assert_true(runs.start(), "the run opens")
	var purse := box.resolve(EagerPurse) as EagerPurse
	assert_not_null(purse, "the factory product is there")
	assert_eq(purse.gold, 1, "it was built by start")
	assert_eq(purse.log, box.resolve(RunLog), "the factory argument was injected")


func test_a_failed_eager_product_refuses_start() -> void:
	box.shutdown()
	box = null
	ProjectSettings.set_setting("ioc/eager_broken", "yes")
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	for err in get_errors():
		err.handled = true
	runs = box.resolve(Runs) as Runs
	assert_false(runs.start(), "a broken eager product blocks the run")
	assert_push_error("no component for EagerNeed")
	assert_push_error("missing field need on EagerBroken")
	assert_false(runs.is_open(), "no run stays open")
	ProjectSettings.set_setting("ioc/eager_broken", "")


func test_bad_marks_are_rejected() -> void:
	assert_true(_has("EagerBadBoth is @Eager and @Lazy."), "both marks are refused")
	assert_true(_has("EagerBadPooled is @Pooled and cannot be @Eager or @Lazy."), "a pool has no init mode")
	assert_true(_has("EagerBadPlain is @Eager without @Component."), "the mark needs a product")
	assert_true(_has("@Eager on EagerBadMember belongs on a class or a factory method."), "a field is refused")
	assert_true(_has("EagerBadMember.ping is @Lazy and is not a factory method."), "a plain method is refused")


func _has(needle: String) -> bool:
	for text in scan_errors:
		if text.find(needle) != -1:
			return true
	return false
