class_name Validator
extends RefCounted

## Reads every Constraint on a script. Fields use the instance values.
## Constructor parameters are checked only when arguments are passed, in
## declaration order. Every constraint runs. The returned list is empty
## when every one matches.


static func validate(instance: Object, arguments: Array = []) -> Array:
	if instance == null:
		push_error("Validation: validate needs an instance.")
		return []
	var script := instance.get_script() as GDScript
	if script == null:
		push_error("Validation: target has no script.")
		return []
	var collector := _Collector.new(instance, arguments)
	AnnotationUtils.for_each_annotation_initialized(Constraint, script, collector.take)
	return collector.violations


class _Collector:
	extends RefCounted

	var instance: Object
	var arguments: Array
	var violations: Array = []

	func _init(target: Object, args: Array) -> void:
		instance = target
		arguments = args

	func take(annotation: Object, target: Object) -> void:
		var constraint := annotation as Constraint
		if constraint == null:
			return
		if target is VariableInfo:
			var variable := target as VariableInfo
			_check(constraint, instance.get(variable.name), String(variable.name))
			return
		if target is ParameterInfo:
			var parameter := target as ParameterInfo
			if String(parameter.function) != "_init" or arguments.is_empty():
				return
			var index := _argument_index(parameter)
			if index < 0 or index >= arguments.size():
				return
			_check(constraint, arguments[index], "_init/%s" % parameter.name)

	func _check(constraint: Constraint, candidate: Variant, member_name: String) -> void:
		if constraint.is_valid(candidate):
			return
		var script := constraint.get_script() as GDScript
		var constraint_name := "Constraint"
		if script != null and not String(script.get_global_name()).is_empty():
			constraint_name = String(script.get_global_name())
		violations.append(Violation.new(member_name, constraint_name, constraint.violation_message(candidate)))

	func _argument_index(parameter: ParameterInfo) -> int:
		var info := ReflectionUtils.get_function_info(parameter.gdscript, parameter.function)
		if info == null:
			return -1
		return info.arguments.find(String(parameter.name))
