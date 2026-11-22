class_name Condition
extends GDScriptAnnotation

## A yes-or-no gate read before a definition is registered. Several conditions
## on the same class or method all have to match. A subclass overrides matches
## and reads the ConditionContext. The container does not special-case the
## subclass name.


func matches(_context: ConditionContext) -> bool:
	return false


func depends_on_registry() -> bool:
	return false


func component_script(type_name: String, label: String) -> GDScript:
	var named := type_name.strip_edges()
	if named.is_empty():
		push_error("IOC: %s needs a type_name." % label)
		return null
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) != named:
			continue
		if String(entry.get("language", "")) != "GDScript":
			push_error("IOC: %s type %s is not a GDScript class." % [label, named])
			return null
		var script := load(String(entry.get("path", ""))) as GDScript
		if script == null:
			push_error("IOC: %s could not load %s." % [label, named])
			return null
		return script
	push_error("IOC: %s type %s is not a global class." % [label, named])
	return null


static func type_present(type_name: String) -> bool:
	if ClassDB.class_exists(type_name):
		return true
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) == type_name:
			return true
	return false
