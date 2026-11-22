class_name PropertyBinder
extends RefCounted

## Writes PropertyEnvironment into @export fields. A missing key keeps the
## field default. An extra key is ignored. int may fill a float. Any other
## type mismatch fails the whole object. Only int, float, bool, and String
## are accepted.


func bind(instance: Object, prefix: String, environment: PropertyEnvironment) -> bool:
	var script := instance.get_script() as GDScript
	if script == null:
		push_error("IOC: property target has no script.")
		return false
	var seen := {}
	for property in script.get_script_property_list():
		var property_name := String(property.get("name", ""))
		if property_name.is_empty() or seen.has(property_name):
			continue
		var usage := int(property.get("usage", 0))
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		if (usage & PROPERTY_USAGE_EDITOR) == 0:
			continue
		seen[property_name] = true
		var type_code := int(property.get("type", TYPE_NIL))
		if not _supported(type_code):
			push_error("IOC: %s.%s must be int, float, bool, or String." % [_script_name(script), property_name])
			return false
		var key := "%s/%s" % [prefix, property_name]
		if not environment.contains(key):
			continue
		var value: Variant = environment.get_value(key)
		if not _fits(type_code, value):
			push_error("IOC: %s.%s cannot take %s for %s." % [_script_name(script), property_name, type_string(typeof(value)), type_string(type_code)])
			return false
		instance.set(StringName(property_name), _coerce(type_code, value))
	return true


func _supported(type_code: int) -> bool:
	return type_code == TYPE_INT or type_code == TYPE_FLOAT or type_code == TYPE_BOOL or type_code == TYPE_STRING


func _fits(type_code: int, value: Variant) -> bool:
	var value_type := typeof(value)
	if type_code == TYPE_FLOAT and value_type == TYPE_INT:
		return true
	return value_type == type_code


func _coerce(type_code: int, value: Variant) -> Variant:
	if type_code == TYPE_FLOAT:
		return float(value)
	return value


func _script_name(script: GDScript) -> String:
	if script == null:
		return "?"
	var global_name := String(script.get_global_name())
	if global_name.is_empty():
		return script.resource_path.get_file()
	return global_name
