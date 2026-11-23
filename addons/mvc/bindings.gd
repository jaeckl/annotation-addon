class_name Bindings
extends RefCounted

## text, field, property, and error are binders. A binder listens from the
## moment it is built, so the property has to be read after that. Three forms
## do that: from on the next line, link with the binder as the first argument,
## and from with a lambda that returns the property. error listens to the
## message kept when a property is rejected. A custom control extends Binder.


static func text(label: Label) -> TextBinding:
	return TextBinding.new(label)


static func field(line: LineEdit) -> FieldBinding:
	return FieldBinding.new(line)


static func property(node: Node, path: NodePath) -> ValueBinding:
	return ValueBinding.new(node, path)


static func error(label: Label) -> ErrorBinding:
	return ErrorBinding.new(label)


## One line: Bindings.link(Bindings.text(label), model.gold). Arguments are
## evaluated left to right, so the binder listens before the property is read.
static func link(binder: Binder, value: Variant) -> void:
	if binder == null:
		PropNotify.disarm()
		push_error("MVC: link needs a binder.")
		return
	binder.from(value)


static func on(source: Signal) -> SignalBinding:
	return SignalBinding.new(source)


static func _one_read(target_name: String) -> Dictionary:
	var found := PropNotify.take()
	if found.size() == 1:
		return found[0]
	if found.is_empty():
		push_error("MVC: %s binds a property." % target_name)
	else:
		push_error("MVC: %s binds one property." % target_name)
	return {}


static func _who(callback: Callable) -> String:
	var object: Object = callback.get_object()
	var method := String(callback.get_method())
	if object == null:
		return method
	return "%s.%s" % [_global_name(object), method]


static func _global_name(object: Object) -> String:
	var script: Object = object.get_script()
	while script is GDScript:
		var global_name := (script as GDScript).get_global_name()
		if global_name != &"":
			return String(global_name)
		script = (script as GDScript).get_base_script()
	return object.get_class()


class TextBinding:
	extends Binder

	var label: Label


	func _init(target: Label) -> void:
		label = target
		super()


	func _node() -> Node:
		return label


	func _kind() -> String:
		return "text"


	func _absent() -> String:
		return "MVC: text needs a label."


	func _show(next: Variant) -> void:
		if is_instance_valid(label):
			label.text = str(next)


class FieldBinding:
	extends Binder

	var line: LineEdit
	var _writing := false
	var _owner: Object
	var _property: StringName
	var _sample: Variant


	func _init(target: LineEdit) -> void:
		line = target
		super()


	func _node() -> Node:
		return line


	func _kind() -> String:
		return "field"


	func _absent() -> String:
		return "MVC: field needs a line."


	func _attach(owner: Object, property: StringName, value: Variant) -> void:
		_owner = owner
		_property = property
		_sample = value
		_write(str(value))
		PropNotify.listen(owner, property, func(next: Variant) -> void:
			if is_instance_valid(line):
				_write(str(next))
		)
		if line != null and not line.text_changed.is_connected(_on_text):
			line.text_changed.connect(_on_text)


	func _on_text(next: String) -> void:
		if _writing or not is_instance_valid(_owner):
			return
		_owner.set(_property, _coerce(next, _sample))


	func _write(next: String) -> void:
		if _writing or line == null:
			return
		_writing = true
		line.text = next
		_writing = false


	func _coerce(next: String, sample: Variant) -> Variant:
		match typeof(sample):
			TYPE_INT:
				return next.to_int() if next.is_valid_int() else 0
			TYPE_FLOAT:
				return next.to_float() if next.is_valid_float() else 0.0
			TYPE_BOOL:
				return next == "true"
			_:
				return next


class ValueBinding:
	extends Binder

	var node: Node
	var path: NodePath


	func _init(target: Node, property_path: NodePath) -> void:
		node = target
		path = property_path
		super()


	func _node() -> Node:
		return node


	func _kind() -> String:
		return "property"


	func _absent() -> String:
		return "MVC: property needs a node."


	func _attach(owner: Object, property: StringName, value: Variant) -> void:
		var indexed := _indexed(path)
		if node != null:
			node.set_indexed(indexed, value)
		PropNotify.listen(owner, property, func(next: Variant) -> void:
			if is_instance_valid(node):
				node.set_indexed(indexed, next)
		)


	func _indexed(property_path: NodePath) -> NodePath:
		if property_path.get_subname_count() > 0:
			return property_path
		return NodePath(":%s" % String(property_path))


class ErrorBinding:
	extends Binder

	var label: Label


	func _init(target: Label) -> void:
		label = target
		super()


	func _node() -> Node:
		return label


	func _kind() -> String:
		return "error"


	func _absent() -> String:
		return "MVC: error needs a label."


	func _attach(owner: Object, property: StringName, _value: Variant) -> void:
		PropNotify.listen_error(owner, property, func(message: String) -> void:
			if is_instance_valid(label):
				label.text = message
		)


class SignalBinding:
	extends RefCounted

	var source: Signal


	func _init(signal_source: Signal) -> void:
		source = signal_source


	func to(callback: Callable) -> void:
		var who := Bindings._who(callback)
		if source.is_null():
			push_error("MVC: %s cannot listen." % who)
			return
		var signal_name := String(source.get_name())
		if source.is_connected(callback):
			push_error("MVC: %s is already connected to %s." % [who, signal_name])
			return
		var error := source.connect(callback)
		if error != OK:
			push_error("MVC: %s cannot listen to %s." % [who, signal_name])
