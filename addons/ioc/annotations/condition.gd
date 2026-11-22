class_name Condition
extends GDScriptAnnotation

## A yes-or-no gate read before a definition is registered. Several conditions
## on the same class or method all have to match. A subclass overrides matches.
## The container does not special-case the subclass name.


func matches(_environment: PropertyEnvironment) -> bool:
	return false


static func type_present(type_name: String) -> bool:
	if ClassDB.class_exists(type_name):
		return true
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) == type_name:
			return true
	return false
