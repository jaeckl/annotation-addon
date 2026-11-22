class_name Preparer
extends RefCounted

## Reads every Preparation on a script. Fields are written back. Constructor
## parameters change only when arguments are passed, in declaration order.
## Returns false when a preparation fails or the result cannot be stored.
## The previous value stays in that case.


static func prepare(instance: Object, arguments: Array = []) -> bool:
	if instance == null:
		push_error("Prepare: prepare needs an instance.")
		return false
	var script := instance.get_script() as GDScript
	if script == null:
		push_error("Prepare: target has no script.")
		return false
	var writer := _Writer.new(instance, arguments)
	AnnotationUtils.for_each_annotation_initialized(Preparation, script, writer.take)
	return writer.ok


## One field, without writing it. A setter calls this so the write cannot
## re-enter. ok is false when a preparation fails or the result cannot be
## stored, and value is then the original value.
static func prepare_member(script: GDScript, member_name: StringName, value: Variant) -> Dictionary:
	if script == null:
		return {"ok": true, "value": value, "message": "", "name": ""}
	var walker := _Member.new(_script_name(script), String(member_name), value)
	var current := script
	while current != null:
		AnnotationUtils.for_each_annotation_initialized(Preparation, current, walker.take)
		if not walker.ok:
			return {"ok": false, "value": value, "message": walker.message, "name": walker.prep_name}
		current = current.get_base_script()
	return {"ok": true, "value": walker.value, "message": "", "name": ""}


static func _script_name(script: GDScript) -> String:
	if script == null:
		return "?"
	var global_name := String(script.get_global_name())
	if global_name.is_empty():
		return script.resource_path.get_file()
	return global_name


class _Writer:
	extends RefCounted

	var instance: Object
	var arguments: Array
	var ok := true

	func _init(target: Object, args: Array) -> void:
		instance = target
		arguments = args

	func take(annotation: Object, target: Object) -> void:
		var preparation := annotation as Preparation
		if preparation == null:
			return
		if target is VariableInfo:
			var variable := target as VariableInfo
			if variable.is_static:
				return
			_apply(preparation, instance.get(variable.name), int(variable.type), String(variable.name), func(value: Variant) -> void: instance.set(variable.name, value))
			return
		if target is ParameterInfo:
			var parameter := target as ParameterInfo
			if String(parameter.function) != "_init" or arguments.is_empty():
				return
			var index := _argument_index(parameter)
			if index < 0 or index >= arguments.size():
				return
			_apply(preparation, arguments[index], int(parameter.type), "_init/%s" % parameter.name, func(value: Variant) -> void: arguments[index] = value)

	func _apply(preparation: Preparation, current: Variant, type_code: int, member_name: String, write: Callable) -> void:
		preparation.reset()
		var result: Variant = preparation.apply(current)
		if preparation.failed():
			ok = false
			return
		if _fits(type_code, result):
			write.call(result)
			return
		var script := preparation.get_script() as GDScript
		var preparation_name := "Preparation"
		if script != null and not String(script.get_global_name()).is_empty():
			preparation_name = String(script.get_global_name())
		push_error("Prepare: %s.%s cannot store %s from %s." % [_owner_name(), member_name, type_string(typeof(result)), preparation_name])
		ok = false

	func _fits(type_code: int, result: Variant) -> bool:
		if type_code == TYPE_NIL:
			return true
		var got := typeof(result)
		if got == type_code:
			return true
		return type_code == TYPE_FLOAT and got == TYPE_INT

	func _argument_index(parameter: ParameterInfo) -> int:
		var info := ReflectionUtils.get_function_info(parameter.gdscript, parameter.function)
		if info == null:
			return -1
		return info.arguments.find(String(parameter.name))

	func _owner_name() -> String:
		var script := instance.get_script() as GDScript
		if script == null:
			return "?"
		var global_name := String(script.get_global_name())
		if global_name.is_empty():
			return script.resource_path.get_file()
		return global_name


class _Member:
	extends RefCounted

	var owner: String
	var member: String
	var value: Variant
	var ok := true
	var message := ""
	var prep_name := ""

	func _init(owner_name: String, member_name: String, start: Variant) -> void:
		owner = owner_name
		member = member_name
		value = start

	func take(annotation: Object, target: Object) -> void:
		if not ok:
			return
		var preparation := annotation as Preparation
		if preparation == null or not (target is VariableInfo):
			return
		var variable := target as VariableInfo
		if variable.is_static or String(variable.name) != member:
			return
		preparation.reset()
		var result: Variant = preparation.apply(value)
		prep_name = _prep_name(preparation)
		if preparation.failed():
			ok = false
			message = preparation.failure_message()
			return
		if _fits(int(variable.type), result):
			value = result
			return
		ok = false
		message = "Prepare: %s.%s cannot store %s from %s." % [owner, member, type_string(typeof(result)), prep_name]
		push_error(message)

	func _fits(type_code: int, result: Variant) -> bool:
		if type_code == TYPE_NIL:
			return true
		var got := typeof(result)
		if got == type_code:
			return true
		return type_code == TYPE_FLOAT and got == TYPE_INT

	func _prep_name(preparation: Preparation) -> String:
		var script := preparation.get_script() as GDScript
		if script != null and not String(script.get_global_name()).is_empty():
			return String(script.get_global_name())
		return "Preparation"
