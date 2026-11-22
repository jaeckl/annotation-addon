extends GutTest


func before_each() -> void:
	PropNotify.clear()


func after_each() -> void:
	PropNotify.clear()


func test_text_follows_a_manual_property() -> void:
	var model := ManualGold.new()
	var label := Label.new()
	var text := Bindings.text(label)
	text.from(model.gold)
	assert_eq(label.text, "2", "the label takes the current value")
	model.gold = 5
	assert_eq(label.text, "5", "the label follows the setter")
	var ignored := model.gold
	model.gold = 6
	assert_eq(label.text, "6", "a read outside from still notifies the binding")
	assert_eq(ignored, 5, "the read saw the previous value")
	label.free()


func test_a_signal_wrapper_connects_once() -> void:
	var button := Button.new()
	var hits := {"count": 0}
	var listener := func() -> void:
		hits["count"] = int(hits["count"]) + 1
	Bindings.on(button.pressed).to(listener)
	button.pressed.emit()
	assert_eq(int(hits["count"]), 1, "the wrapper calls the method")
	Bindings.on(button.pressed).to(listener)
	assert_engine_error("is already connected to pressed")
	button.free()


func test_show_hides_the_previous_view() -> void:
	var host := ScreenHost.new()
	var first := Control.new()
	var second := Control.new()
	host.show(first)
	assert_true(first.visible, "show reveals the view")
	host.show(second)
	assert_false(first.visible, "the previous view is hidden")
	assert_true(second.visible, "the new view is shown")
	host.hide(second)
	assert_false(second.visible, "hide conceals that view")
	first.free()
	second.free()
