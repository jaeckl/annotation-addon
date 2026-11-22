class_name IOCContainer
extends RefCounted

## App-scope container for the first slice. Discovers global classes, registers
## @Component classes and @Configuration methods, and resolves them by type.
## Scene scope and enter-tree injection of scene-placed nodes are not here.
var definitions: Array = []
var matcher: QualifierMatcher
var selector: CandidateSelector
var app_scope: AppScope
var _scripts: Dictionary = {}
var _factories: Dictionary = {}
var _creating: Array = []
var _tree: SceneTree


func setup(tree: SceneTree) -> void:
	_tree = tree
	matcher = QualifierMatcher.new()
	selector = CandidateSelector.new(matcher)
	app_scope = AppScope.new()
	app_scope.setup(tree)


func discover() -> void:
	_scripts.clear()
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("language", "")) != "GDScript":
			continue
		var script := load(String(entry.get("path", ""))) as GDScript
		if script == null:
			continue
		_scripts[String(entry.get("class", ""))] = script
	for global_name in _scripts:
		_scan(_scripts[global_name])


func configuration(script: GDScript) -> Object:
	return _factories.get(script, null)


func resolve(type: GDScript, qualifiers: Array = [], _from_node: Node = null) -> Object:
	if type == null:
		push_error("IOC: resolve needs a script.")
		return null
	var found: Array = selector.select(definitions, type, qualifiers)
	if found.size() != 1:
		_report_selection(type, qualifiers, found)
		return null
	var definition := found[0] as ComponentDefinition
	if definition in _creating:
		push_error("IOC: cycle while creating %s." % definition.label)
		return null
	var existing := app_scope.fetch(definition)
	if existing != null:
		return existing
	_creating.append(definition)
	var instance := _construct(definition)
	if instance != null and not _inject_fields(instance, definition):
		instance = null
	if instance != null:
		app_scope.store(definition, instance)
		app_scope.attach(instance)
	_creating.erase(definition)
	return instance


func _scan(script: GDScript) -> void:
	if AnnotationUtils.has_annotation(script, Configuration):
		_register_configuration(script)
		return
	if AnnotationUtils.has_annotation(script, Component):
		_register_class_product(script)
		return
	_reject_orphan_methods(script)


func _register_configuration(script: GDScript) -> void:
	if not script.can_instantiate():
		push_error("IOC: configuration %s cannot be constructed." % _script_name(script))
		return
	var factory: Object = script.callv(&"new", [])
	if factory == null:
		push_error("IOC: configuration %s produced null." % _script_name(script))
		return
	_factories[script] = factory
	var bucket := {"script": script, "factory": factory}
	AnnotationUtils.for_each_annotation_initialized(Component, script, _take_configuration_component.bind(bucket))


func _take_configuration_component(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	if target is ScriptInfo:
		return
	if target is FunctionInfo:
		var info := target as FunctionInfo
		if info.is_static:
			push_error("IOC: %s.%s is static. Factory methods are called on the configuration instance." % [_script_name(script), info.name])
			return
		_register_method(script, bucket["factory"], info.name)
		return
	push_error("IOC: @Component on %s is not a class or a factory method." % _script_name(script))


func _register_method(script: GDScript, factory: Object, method: StringName) -> void:
	var return_script := _method_return_script(script, method)
	if return_script == null:
		push_error("IOC: %s.%s needs a GDScript return type." % [_script_name(script), method])
		return
	var parameters := _parameters(script, method)
	if parameters == null:
		return
	var fields := _fields(return_script)
	if fields == null:
		return
	_add_definition(return_script, _qualifiers(script, "func", method, &""), "%s.%s" % [_script_name(script), method], script, factory, method, parameters, fields)


func _register_class_product(script: GDScript) -> void:
	if not script.can_instantiate():
		push_error("IOC: component %s cannot be constructed." % _script_name(script))
		return
	var parameters := _parameters(script, &"_init")
	if parameters == null:
		return
	var fields := _fields(script)
	if fields == null:
		return
	_add_definition(script, _qualifiers(script, "script", &"", &""), _script_name(script), script, null, &"", parameters, fields)


func _reject_orphan_methods(script: GDScript) -> void:
	var bucket := {"script": script}
	AnnotationUtils.for_each_annotation_initialized(Component, script, _take_orphan_component.bind(bucket))


func _take_orphan_component(annotation: Object, target: Object, bucket: Dictionary) -> void:
	if target is FunctionInfo:
		var info := target as FunctionInfo
		push_error("IOC: %s.%s is @Component but the class is not @Configuration." % [_script_name(bucket["script"]), info.name])


func _add_definition(type: GDScript, qualifiers: Array, label: String, owner_script: GDScript, factory: Object, method: StringName, parameters: Array, fields: Array) -> void:
	var definition := ComponentDefinition.new()
	definition.type = type
	definition.qualifiers = qualifiers
	definition.label = label
	definition.owner_script = owner_script
	definition.factory = factory
	definition.method = method
	definition.parameters = parameters
	definition.fields = fields
	definitions.append(definition)


func _parameters(script: GDScript, method: StringName) -> Variant:
	var parameters: Array = []
	for info in ReflectionUtils.get_parameter_list(script, method):
		var parameter := info as ParameterInfo
		var parameter_script := _script_from_type(parameter.type, parameter.type_class)
		if parameter_script == null:
			push_error("IOC: %s.%s parameter %s needs a global GDScript type." % [_script_name(script), method, parameter.name])
			return null
		parameters.append({
			"name": String(parameter.name),
			"type": parameter_script,
			"qualifiers": _qualifiers(script, "param", method, parameter.name),
		})
	return parameters


func _fields(script: GDScript) -> Variant:
	var fields: Array = []
	var current := script
	while current != null:
		var bucket := {"script": current, "fields": fields, "failed": false}
		AnnotationUtils.for_each_annotation_initialized(Inject, current, _take_field.bind(bucket))
		if bucket["failed"]:
			return null
		current = current.get_base_script()
	return fields


func _take_field(annotation: Object, target: Object, bucket: Dictionary) -> void:
	if not (target is VariableInfo):
		return
	var info := target as VariableInfo
	var script := bucket["script"] as GDScript
	if info.is_static:
		push_error("IOC: %s.%s is static and cannot be injected." % [_script_name(script), info.name])
		bucket["failed"] = true
		return
	var field_script := _script_from_type(info.type, info.type_class)
	if field_script == null:
		push_error("IOC: %s.%s needs a global GDScript type." % [_script_name(script), info.name])
		bucket["failed"] = true
		return
	bucket["fields"].append({
		"name": String(info.name),
		"type": field_script,
		"qualifiers": _qualifiers(script, "var", info.name, &""),
	})


func _qualifiers(script: GDScript, kind: String, member: StringName, parameter: StringName) -> Array:
	var found: Array = []
	var bucket := {
		"kind": kind,
		"member": member,
		"parameter": parameter,
		"found": found,
	}
	AnnotationUtils.for_each_annotation_initialized(Qualifier, script, _take_qualifier.bind(bucket))
	return found


func _take_qualifier(annotation: Object, target: Object, bucket: Dictionary) -> void:
	if _is_qualifier_target(target, String(bucket["kind"]), bucket["member"], bucket["parameter"]):
		bucket["found"].append(annotation)


func _is_qualifier_target(target: Object, kind: String, member: StringName, parameter: StringName) -> bool:
	match kind:
		"script":
			return target is ScriptInfo
		"func":
			return target is FunctionInfo and (target as FunctionInfo).name == member
		"var":
			return target is VariableInfo and (target as VariableInfo).name == member
		"param":
			return target is ParameterInfo and (target as ParameterInfo).function == member and (target as ParameterInfo).name == parameter
		_:
			return false


func _construct(definition: ComponentDefinition) -> Object:
	var args: Array = []
	for parameter in definition.parameters:
		var value: Object = resolve(parameter["type"], parameter["qualifiers"])
		if value == null:
			push_error("IOC: missing argument %s for %s." % [parameter["name"], definition.label])
			return null
		args.append(value)
	var instance: Variant = null
	if definition.factory != null:
		instance = definition.factory.callv(definition.method, args)
	else:
		instance = definition.owner_script.callv(&"new", args)
	if instance == null or not (instance is Object):
		push_error("IOC: %s produced null." % definition.label)
		return null
	return instance


func _inject_fields(instance: Object, definition: ComponentDefinition) -> bool:
	for field in definition.fields:
		var value: Object = resolve(field["type"], field["qualifiers"])
		if value == null:
			push_error("IOC: missing field %s on %s." % [field["name"], definition.label])
			return false
		instance.set(StringName(field["name"]), value)
	return true


func _method_return_script(script: GDScript, method: StringName) -> GDScript:
	for info in script.get_script_method_list():
		if StringName(info.get("name", &"")) != method:
			continue
		var returned: Dictionary = info.get("return", {})
		if int(returned.get("type", TYPE_NIL)) != TYPE_OBJECT:
			return null
		var type_name := String(returned.get("class_name", ""))
		if type_name.is_empty():
			type_name = String(returned.get("hint_string", ""))
		return _scripts.get(type_name) as GDScript
	return null


func _script_from_type(type_code: int, type_class: StringName) -> GDScript:
	if type_code != TYPE_OBJECT or String(type_class).is_empty():
		return null
	return _scripts.get(String(type_class)) as GDScript


func _report_selection(type: GDScript, qualifiers: Array, found: Array) -> void:
	var requested := _script_name(type)
	var needed := _describe_qualifiers(qualifiers)
	if found.is_empty():
		push_error("IOC: no component for %s [%s]." % [requested, needed])
		return
	var labels: PackedStringArray = PackedStringArray()
	for definition in found:
		var product := definition as ComponentDefinition
		labels.append("%s [%s]" % [product.label, _describe_qualifiers(product.qualifiers)])
	push_error("IOC: several components for %s [%s]: %s." % [requested, needed, ", ".join(labels)])


func _describe_qualifiers(qualifiers: Array) -> String:
	if qualifiers.is_empty():
		return "-"
	var parts: PackedStringArray = PackedStringArray()
	for annotation in qualifiers:
		parts.append(matcher.describe(annotation))
	return ", ".join(parts)


func _script_name(script: GDScript) -> String:
	if script == null:
		return "?"
	var global_name := String(script.get_global_name())
	if global_name.is_empty():
		return script.resource_path.get_file()
	return global_name
