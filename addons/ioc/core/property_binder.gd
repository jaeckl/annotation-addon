class_name PropertyBinder
extends RefCounted

## Writes PropertyEnvironment into @export fields. A missing key keeps the
## field default. An extra key is ignored. converters is walked in order.
## The first PropertyConverter that accepts the value produces the stored
## value. A result of the wrong type fails the whole object. Only int,
## float, bool, and String fields are accepted.
var converters: Array = []


func _init() -> void:
	converters = [ScalarPropertyConverter.new()]


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
		var converted := _convert(script, property_name, type_code, value)
		if not converted["ok"]:
			return false
		instance.set(StringName(property_name), converted["value"])
	return _passes_validation(instance, script)


func _convert(script: GDScript, property_name: String, type_code: int, value: Variant) -> Dictionary:
	for converter in converters:
		var candidate := converter as PropertyConverter
		if candidate == null or not candidate.handles(type_code, value):
			continue
		var converted: Variant = candidate.convert(type_code, value)
		if typeof(converted) != type_code:
			push_error("IOC: %s.%s converter %s produced %s for %s." % [_script_name(script), property_name, _script_name(candidate.get_script()), type_string(typeof(converted)), type_string(type_code)])
			return {"ok": false}
		return {"ok": true, "value": converted}
	push_error("IOC: %s.%s cannot take %s for %s." % [_script_name(script), property_name, type_string(typeof(value)), type_string(type_code)])
	return {"ok": false}


func _supported(type_code: int) -> bool:
	return type_code == TYPE_INT or type_code == TYPE_FLOAT or type_code == TYPE_BOOL or type_code == TYPE_STRING


func _passes_validation(instance: Object, script: GDScript) -> bool:
	# The validation addon is optional. A missing Validator skips the check.
	# This file does not name that class, so the binder still parses without it.
	var validator := _validation_script()
	if validator == null:
		return true
	var violations: Variant = validator.call(&"validate", instance)
	if not (violations is Array) or violations.is_empty():
		return true
	var parts := PackedStringArray()
	for item in violations:
		if item == null:
			continue
		parts.append("%s %s" % [item.get("member"), item.get("message")])
	push_error("IOC: %s failed validation. %s" % [_script_name(script), "; ".join(parts)])
	return false


func _validation_script() -> GDScript:
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) != "Validator":
			continue
		if String(entry.get("language", "")) != "GDScript":
			return null
		return load(String(entry.get("path", ""))) as GDScript
	return null


func _script_name(script: GDScript) -> String:
	if script == null:
		return "?"
	var global_name := String(script.get_global_name())
	if global_name.is_empty():
		return script.resource_path.get_file()
	return global_name
