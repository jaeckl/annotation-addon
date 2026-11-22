class_name QualifierMatcher
extends RefCounted

## Default qualifier policy. Each required annotation needs one annotation on
## the candidate with the same class and the same attribute values. Extra
## annotations on the candidate are ignored. No required annotations matches
## every candidate. A subclass of Qualifier needs no other matcher.


func matches(candidate: Array, required: Array) -> bool:
	if required.is_empty():
		return true
	var remaining := candidate.duplicate()
	for required_annotation in required:
		var found := -1
		for index in remaining.size():
			if _same(remaining[index], required_annotation):
				found = index
				break
		if found < 0:
			return false
		remaining.remove_at(found)
	return true


func describe(annotation: Object) -> String:
	var script := annotation.get_script() as GDScript
	var name := _script_name(script)
	var parts: PackedStringArray = PackedStringArray()
	for key in attributes_of(annotation):
		parts.append("%s=%s" % [key, annotation.get(key)])
	return "%s(%s)" % [name, ", ".join(parts)]


func attributes_of(annotation: Object) -> Dictionary:
	var values := {}
	var script := annotation.get_script() as GDScript
	while script != null:
		for property in script.get_script_property_list():
			var property_name := String(property.get("name", ""))
			if property_name.is_empty() or values.has(property_name):
				continue
			if (int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			values[property_name] = annotation.get(property_name)
		script = script.get_base_script()
	return values


func _same(left: Object, right: Object) -> bool:
	var left_script := left.get_script() as GDScript
	var right_script := right.get_script() as GDScript
	if left_script == null or right_script == null or left_script != right_script:
		return false
	return attributes_of(left) == attributes_of(right)


func _script_name(script: GDScript) -> String:
	if script == null:
		return "?"
	var global_name := String(script.get_global_name())
	if global_name.is_empty():
		return script.resource_path.get_file()
	return global_name
