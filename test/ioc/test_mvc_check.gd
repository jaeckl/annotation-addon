extends GutTest

var box: IOCContainer


func before_each() -> void:
	PropNotify.clear()
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	_quiet()


func after_each() -> void:
	if box != null:
		box.shutdown()
	box = null
	await get_tree().process_frame
	for child in get_tree().root.get_children():
		if child is MvcShopView:
			child.free()
	PropNotify.clear()
	_quiet()


func test_a_property_is_checked_before_it_is_stored() -> void:
	var shop := box.resolve(MvcCheck) as MvcCheck
	await get_tree().process_frame
	_quiet()
	assert_eq(shop.model.title, "hall", "trim stores the prepared text")
	assert_eq(shop.title_label.text, "hall", "the label shows the prepared text")
	assert_eq(shop.model.gold, 0, "a rejected assignment keeps the previous value")
	assert_true(shop.error_label.text.begins_with("must be at most 9"), shop.error_label.text)
	assert_eq(shop.hits.size(), 1, "the handler hears the stored failure")
	assert_eq(String(shop.hits[0]), "gold", "the handler receives the member")
	assert_eq(shop.attempts[0], 40, "the violation carries the rejected value")
	assert_engine_error("MvcChecked.gold must be at most")
	shop.model.gold = 4
	assert_eq(shop.model.gold, 4, "an accepted assignment is stored")
	assert_eq(shop.error_label.text, "", "an accepted assignment clears the message")
	assert_eq(shop.hits.size(), 1, "a success does not call the handler")
	shop.model.title = "  hi  "
	assert_eq(shop.model.title, "hi", "trim stores the later assignment")
	assert_eq(shop.title_label.text, "hi", "the label follows the prepared text")
	var line := LineEdit.new()
	var typed := Bindings.field(line)
	typed.from(shop.model.gold)
	line.text = "40"
	line.text_changed.emit(line.text)
	assert_eq(shop.model.gold, 4, "a rejected line keeps the model")
	assert_eq(line.text, "4", "the line snaps back")
	assert_true(shop.error_label.text.begins_with("must be at most 9"), shop.error_label.text)
	assert_engine_error("MvcChecked.gold must be at most")
	shop.trap = true
	shop.model.gold = 40
	assert_eq(shop.model.gold, 4, "a write during the check is dropped")
	assert_engine_error("MvcChecked.gold is assigned while it is being checked.")
	assert_engine_error("MvcChecked.gold must be at most")
	shop.model.title = "   "
	assert_eq(shop.model.title, "hi", "an empty title keeps the previous value")
	assert_eq(shop.title_label.text, "hi", "the title label keeps the previous text")
	assert_engine_error("MvcChecked.title must not be empty")
	assert_true(shop.hits.has("title"), "the handler hears the title")
	shop.model.pace = 3
	assert_eq(shop.model.pace, 0, "a failed preparation keeps the previous value")
	assert_true(shop.hits.has("pace"), "the handler hears the preparation")
	assert_engine_error("Prepare: @Clamp needs a minimum at or below the maximum.")
	line.free()


func test_an_advisor_rewrites_before_validation_and_can_reject() -> void:
	var shop := box.resolve(MvcCheck) as MvcCheck
	await get_tree().process_frame
	_quiet()
	assert_engine_error("MvcChecked.gold must be at most")
	shop.model.gold = 99
	assert_eq(shop.model.gold, 5, "the advisor rewrites the value before validation")
	assert_eq(shop.error_label.text, "", "a rewritten value clears the message")
	assert_eq(shop.hits.size(), 1, "a rewrite does not call the handler")
	shop.model.gold = -1
	assert_eq(shop.model.gold, 5, "a rejected advisor keeps the previous value")
	assert_eq(shop.error_label.text, "gold stays up", "the label shows the advisor message")
	assert_eq(shop.attempts[shop.attempts.size() - 1], -1, "the violation carries the advisor value")
	assert_engine_error("MvcChecked.gold gold stays up")


func test_a_custom_binder_follows_the_property() -> void:
	var stash := box.resolve(MvcStash) as MvcStash
	var label := Label.new()
	var gauge := MvcGauge.new(label)
	gauge.from(stash.gold)
	assert_eq(label.text, "g:0", "the binder starts at the property value")
	stash.gold = 2
	assert_eq(label.text, "g:2", "the binder follows the assignment")
	label.free()


func test_a_handler_belongs_on_a_controller() -> void:
	box.resolve(MvcBadHandler)
	box.resolve(MvcBadArity)
	await get_tree().process_frame
	_quiet()
	assert_engine_error("MvcBadHandler handles validation on a non-controller.")
	assert_engine_error("MvcBadArity.rejected must take one Violation.")


func _quiet() -> void:
	for err in get_errors():
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("NoSuchAddon") != -1 or text.find("not a global class") != -1:
			err.handled = true
