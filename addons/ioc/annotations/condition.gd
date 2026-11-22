class_name Condition
extends GDScriptAnnotation

## A yes-or-no gate read before a definition is registered. Several conditions
## on the same class or method all have to match. A subclass overrides matches.
## The container does not special-case the subclass name.
## registry is the product scripts visible to a depends_on_registry condition.
var registry: Array = []


func matches(_environment: PropertyEnvironment) -> bool:
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


func registry_has(type: GDScript) -> bool:
	for entry in registry:
		var current := entry as GDScript
		while current != null:
			if current == type:
				return true
			current = current.get_base_script()
	return false


static func type_present(type_name: String) -> bool:
	if ClassDB.class_exists(type_name):
		return true
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) == type_name:
			return true
	return false
