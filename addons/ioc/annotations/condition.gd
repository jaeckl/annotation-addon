class_name Condition
extends GDScriptAnnotation

## A yes-or-no gate read before a definition is registered. Several conditions
## on the same class or method all have to match. A subclass overrides matches
## and reads the ConditionContext. @Condition([OnTownMusic, OnGameClock]) runs
## each listed class, and every one has to match. The container does not
## special-case the subclass name.
var conditions: Array = []


static var _asking: Array = []


func matches(context: ConditionContext) -> bool:
	if not (conditions is Array) or conditions.is_empty():
		push_error("IOC: @Condition needs a condition list.")
		return false
	for item in conditions:
		var condition := _listed_condition(item)
		if condition == null or not condition.matches(context):
			return false
	return true


func depends_on_registry() -> bool:
	return _ask(&"depends_on_registry")


func depends_on_scene() -> bool:
	return _ask(&"depends_on_scene")


func _ask(method: StringName) -> bool:
	# A fresh annotation instance does not receive the default array. A listed
	# class that does not override this method must not walk that slot again.
	if not (conditions is Array):
		return false
	for item in conditions:
		var script := item as GDScript
		if script == null or _asking.has(script):
			continue
		_asking.append(script)
		var condition := _peek_condition(script)
		var answer := condition != null and bool(condition.call(method))
		_asking.erase(script)
		if answer:
			return true
	return false


func _listed_condition(item: Variant) -> Condition:
	var script := item as GDScript
	if script == null:
		push_error("IOC: @Condition list needs a GDScript condition class.")
		return null
	if script == Condition or not _is_condition_script(script):
		push_error("IOC: %s is not a Condition." % _script_label(script))
		return null
	var condition := _peek_condition(script)
	if condition == null:
		push_error("IOC: condition %s cannot be constructed." % _script_label(script))
		return null
	return condition


func _peek_condition(item: Variant) -> Condition:
	# Annotation classes extend an abstract native type, so script.new() cannot
	# build one. The annotation factory can.
	var script := item as GDScript
	if script == null or script == Condition or not _is_condition_script(script):
		return null
	var global_name := String(script.get_global_name())
	if global_name.is_empty():
		return null
	return AnnotationUtils.instantiate_annotation({"name": global_name, "values": {}}) as Condition


func _is_condition_script(script: GDScript) -> bool:
	var current := script
	while current != null:
		if current == Condition:
			return true
		current = current.get_base_script()
	return false


func _script_label(script: GDScript) -> String:
	var global_name := String(script.get_global_name())
	if global_name.is_empty():
		return script.resource_path.get_file()
	return global_name


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
