class_name Bindings
extends RefCounted

## text, field, and property start listening. The next line calls from, because
## GDScript evaluates arguments before the call.


static func text(label: Label) -> TextBinding:
	PropNotify.arm()
	return TextBinding.new(label)


static func field(line: LineEdit) -> FieldBinding:
	PropNotify.arm()
	return FieldBinding.new(line)


static func property(node: Node, path: NodePath) -> ValueBinding:
	PropNotify.arm()
	return ValueBinding.new(node, path)


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
	extends RefCounted

	var label: Label
	var _open := true


	func _init(target: Label) -> void:
		label = target


	func from(value: Variant) -> void:
		_open = false
		var target_name := "text"
		if label != null:
			target_name = String(label.name) if not String(label.name).is_empty() else label.get_class()
		var read := Bindings._one_read(target_name)
		if read.is_empty() or label == null:
			if label == null:
				push_error("MVC: text needs a label.")
			return
		var owner: Object = read["owner"]
		var property: StringName = read["property"]
		label.text = str(value)
		PropNotify.listen(owner, property, func(next: Variant) -> void:
			if is_instance_valid(label):
				label.text = str(next)
		)


	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and _open:
			PropNotify.disarm()


class FieldBinding:
	extends RefCounted

	var line: LineEdit
	var _open := true
	var _writing := false
	var _owner: Object
	var _property: StringName
	var _sample: Variant


	func _init(target: LineEdit) -> void:
		line = target


	func from(value: Variant) -> void:
		_open = false
		var target_name := "field"
		if line != null:
			target_name = String(line.name) if not String(line.name).is_empty() else line.get_class()
		var read := Bindings._one_read(target_name)
		if read.is_empty() or line == null:
			if line == null:
				push_error("MVC: field needs a line.")
			return
		var owner: Object = read["owner"]
		var property: StringName = read["property"]
		_owner = owner
		_property = property
		_sample = value
		_write(str(value))
		PropNotify.listen(owner, property, func(next: Variant) -> void:
			if is_instance_valid(line):
				_write(str(next))
		)
		if not line.text_changed.is_connected(_on_text):
			line.text_changed.connect(_on_text)


	func _on_text(next: String) -> void:
		if _writing or not is_instance_valid(_owner):
			return
		_writing = true
		_owner.set(_property, _coerce(next, _sample))
		_writing = false


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


	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and _open:
			PropNotify.disarm()


class ValueBinding:
	extends RefCounted

	var node: Node
	var path: NodePath
	var _open := true


	func _init(target: Node, property_path: NodePath) -> void:
		node = target
		path = property_path


	func from(value: Variant) -> void:
		_open = false
		var target_name := "property"
		if node != null:
			target_name = String(node.name) if not String(node.name).is_empty() else node.get_class()
		var read := Bindings._one_read(target_name)
		if read.is_empty() or node == null:
			if node == null:
				push_error("MVC: property needs a node.")
			return
		var indexed := _indexed(path)
		var owner: Object = read["owner"]
		var property: StringName = read["property"]
		node.set_indexed(indexed, value)
		PropNotify.listen(owner, property, func(next: Variant) -> void:
			if is_instance_valid(node):
				node.set_indexed(indexed, next)
		)


	func _indexed(property_path: NodePath) -> NodePath:
		if property_path.get_subname_count() > 0:
			return property_path
		return NodePath(":%s" % String(property_path))


	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and _open:
			PropNotify.disarm()


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
