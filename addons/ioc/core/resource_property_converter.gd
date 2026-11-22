class_name ResourcePropertyConverter
extends PropertyConverter

## Loads a res:// path into a Resource field, or keeps a value that is
## already that class. A subclass counts. The container places this
## converter after custom spellings and immediately before the scalar
## converter. A missing file, the wrong class, or another scheme sets
## failure and the binder drops the settings object.


func handles(target_type: int, _value: Variant, target_class: String = "") -> bool:
	return target_type == TYPE_OBJECT and is_resource_class(target_class)


func convert(_target_type: int, value: Variant, target_class: String = "") -> Variant:
	failure = ""
	if matches(value, target_class):
		return value
	if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		return _from_path(String(value).strip_edges(), target_class)
	if value is Resource:
		failure = "is not %s." % target_class
		return null
	failure = "cannot take %s for %s." % [type_string(typeof(value)), target_class]
	return null


static func is_resource_class(type_name: String) -> bool:
	var name := type_name.strip_edges()
	if name.is_empty():
		return false
	if name == "Resource":
		return true
	if ClassDB.class_exists(name) and ClassDB.is_parent_class(name, &"Resource"):
		return true
	var script := _global_script(name)
	if script == null:
		return false
	var native := script.get_instance_base_type()
	return native == &"Resource" or ClassDB.is_parent_class(native, &"Resource")


static func matches(value: Variant, type_name: String) -> bool:
	if not (value is Resource):
		return false
	if type_name == "Resource":
		return true
	var script := (value as Object).get_script() as GDScript
	while script != null:
		if String(script.get_global_name()) == type_name:
			return true
		script = script.get_base_script()
	var native := (value as Object).get_class()
	return native == type_name or ClassDB.is_parent_class(native, StringName(type_name))


func _from_path(path: String, target_class: String) -> Variant:
	if not path.begins_with("res://"):
		failure = "must be a res:// path."
		return null
	if not ResourceLoader.exists(path):
		failure = "%s did not load." % path
		return null
	var loaded: Variant = load(path)
	if matches(loaded, target_class):
		return loaded
	failure = "is not %s." % target_class
	return null


static func _global_script(global_name: String) -> GDScript:
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) != global_name:
			continue
		if String(entry.get("language", "")) != "GDScript":
			return null
		return load(String(entry.get("path", ""))) as GDScript
	return null
