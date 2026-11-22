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
		if child is MvcShopView or child is MvcOtherView or child is MvcPlainView or child is MvcNode:
			child.free()
	PropNotify.clear()
	_quiet()


func test_a_label_follows_the_property_and_a_signal_calls_the_method() -> void:
	var shop := box.resolve(MvcShop) as MvcShop
	await get_tree().process_frame
	_quiet()
	assert_eq(shop.gold_label.text, "0", "the label starts at the property value")
	assert_eq(shop.title_label.text, "shop", "a path bind fills the field")
	assert_true(shop.view.visible, "ready shows the view")
	shop.add_button.pressed.emit()
	assert_eq(shop.clicks, 1, "the signal calls the method")
	assert_eq(shop.gold_label.text, "1", "the label follows the assignment")
	shop.stash.rename("hall")
	assert_eq(shop.title_label.text, "hall", "a copied method writes through the setter")
	var log := box.resolve(CallLog) as CallLog
	shop.stash.add_coin()
	assert_eq(shop.stash.gold, 2, "the model method assigns the property")
	assert_eq(shop.gold_label.text, "2", "the label follows the model method")
	assert_true(_saw(log, "before:add_coin"), "advice still wraps the method")
	shop.close()
	assert_false(shop.view.visible, "hide conceals the view")
	Bindings.on(shop.add_button.pressed).to(shop.add)
	assert_engine_error("MvcShop.add is already connected to pressed.")


func test_a_line_and_a_property_follow_the_model() -> void:
	var stash := box.resolve(MvcStash) as MvcStash
	var line := LineEdit.new()
	var typed := Bindings.field(line)
	typed.from(stash.gold)
	assert_eq(line.text, "0", "the line starts at the property value")
	stash.gold = 4
	assert_eq(line.text, "4", "the line follows the property")
	line.text = "9"
	line.text_changed.emit(line.text)
	assert_eq(stash.gold, 9, "typing writes the property")
	var bar := ProgressBar.new()
	var valued := Bindings.property(bar, ^":value")
	valued.from(stash.gold)
	assert_eq(bar.value, 9.0, "the property path starts at the value")
	stash.gold = 2
	assert_eq(bar.value, 2.0, "the property path follows the model")
	line.free()
	bar.free()


func test_a_binding_reads_one_property() -> void:
	var stash := box.resolve(MvcStash) as MvcStash
	var label := Label.new()
	var missing := Bindings.text(label)
	missing.from(0)
	assert_engine_error("Label binds a property.")
	var both := Bindings.text(label)
	both.from(stash.gold + stash.bonus)
	assert_engine_error("Label binds one property.")
	label.free()


func test_a_view_starts_hidden() -> void:
	var view := box.resolve(MvcShopView) as MvcShopView
	await get_tree().process_frame
	_quiet()
	assert_false(view.visible, "a view is hidden until a controller shows it")


func test_bad_marks_are_rejected() -> void:
	box.resolve(MvcBadInit)
	assert_engine_error("MvcBadInit.gold is assigned in _init.")
	box.resolve(MvcBadSetter)
	assert_engine_error("MvcBadSetter.gold already has a setter.")
	box.resolve(MvcBadMethod)
	assert_engine_error("@Property on MvcBadMethod belongs on a field.")
	box.resolve(MvcNode)
	assert_engine_error("MvcNode is @Controller on a Node.")
	box.resolve(MvcPlainView)
	assert_engine_error("MvcPlainView is @View without @Scene.")
	box.resolve(MvcEscape)
	assert_engine_error("MvcEscape.outside leaves the view.")
	box.resolve(MvcMissing)
	assert_engine_error("MvcMissing.not_there is missing.")
	box.resolve(MvcTwo)
	assert_engine_error("MvcTwo injects more than one view.")
	await get_tree().process_frame
	_quiet()


func _saw(log: CallLog, prefix: String) -> bool:
	for call in log.calls:
		if String(call).begins_with(prefix):
			return true
	return false


func _quiet() -> void:
	for err in get_errors():
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("NoSuchAddon") != -1 or text.find("not a global class") != -1:
			err.handled = true
