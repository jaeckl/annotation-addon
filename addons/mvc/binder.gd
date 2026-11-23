class_name Binder
extends RefCounted

## A control bound to one @Property. The constructor starts listening, and
## from takes the property that was read after that. GDScript evaluates the
## arguments of a call before its callee, so binder.from(model.gold) has to
## be a second line. Two forms fit on one line. Bindings.link(binder,
## model.gold) builds the binder as the first argument. from also takes a
## lambda that returns the property, and calls it while listening.
## A subclass implements _node and _show. _attach is the place for a second
## direction, such as a line writing back into the property.
var _open := true


func _init() -> void:
	PropNotify.arm()


func from(value: Variant) -> void:
	_open = false
	var current: Variant = value
	if value is Callable:
		PropNotify.arm()
		current = null
		if (value as Callable).is_valid():
			current = (value as Callable).call()
	var node := _node()
	var read := Bindings._one_read(_target_name(node))
	if read.is_empty() or node == null:
		if node == null:
			push_error(_absent())
		return
	_attach(read["owner"], read["property"], current)


func _node() -> Node:
	return null


func _kind() -> String:
	return "binding"


func _absent() -> String:
	return "MVC: %s needs a node." % _kind()


func _target_name(node: Node) -> String:
	if node == null:
		return _kind()
	var text := String(node.name)
	if text.is_empty():
		return node.get_class()
	return text


func _attach(owner: Object, property: StringName, value: Variant) -> void:
	_show(value)
	PropNotify.listen(owner, property, func(next: Variant) -> void:
		_show(next)
	)


func _show(_value: Variant) -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _open:
		PropNotify.disarm()
