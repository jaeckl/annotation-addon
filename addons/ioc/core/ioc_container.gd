class_name IOCContainer
extends RefCounted

## App-scope container. Discovers global classes, resolves products, and fills
## @Inject on nodes a scene already created when those nodes enter the tree.
## Scene scope is not here.
var definitions: Array = []
var matcher: QualifierMatcher
var selector: CandidateSelector
var app_scope: AppScope
var environment: PropertyEnvironment
var binder: PropertyBinder
var parsers: Array = []
var _property_roots: Array = []
var _scripts: Dictionary = {}
var _factories: Dictionary = {}
var _creating: Array = []
var _field_cache: Dictionary = {}
var _collection_failed := false
var _tree: SceneTree


func setup(tree: SceneTree) -> void:
	_tree = tree
	matcher = QualifierMatcher.new()
	selector = CandidateSelector.new(matcher)
	app_scope = AppScope.new()
	app_scope.setup(tree)
	environment = PropertyEnvironment.new()
	binder = PropertyBinder.new()
	_install_converters()
	parsers = [ResourcePropertySourceParser.new(), ConfigFilePropertySourceParser.new()]
	# Resources first, then cfg. Each pass inserts at index 0, so the cfg
	# files end above the .tres files. The last name inside one pass wins.
	_load_config_directory("res://config", "tres")
	_load_config_directory("res://config", "cfg")
	# Files are already ordered. Each add_first beats them. The last add
	# is the command line, so it wins over the OS and ProjectSettings.
	environment.add_first(ProjectSettingsPropertySource.new())
	environment.add_first(OsEnvironmentPropertySource.new())
	environment.add_first(CommandLinePropertySource.new())
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


func _install_converters() -> void:
	# The scalar converter stays last. Every other global subclass is
	# inserted in front of it, so a custom spelling wins.
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("language", "")) != "GDScript":
			continue
		var script := load(String(entry.get("path", ""))) as GDScript
		if script == null or script == PropertyConverter or script == ScalarPropertyConverter:
			continue
		if not _extends_script(script, PropertyConverter):
			continue
		if not script.can_instantiate():
			push_error("IOC: converter %s cannot be constructed." % _script_name(script))
			continue
		var converter: Object = script.callv(&"new", [])
		if converter == null:
			push_error("IOC: converter %s produced null." % _script_name(script))
			continue
		binder.converters.insert(binder.converters.size() - 1, converter)


func _extends_script(script: GDScript, base: GDScript) -> bool:
	var current := script.get_base_script()
	while current != null:
		if current == base:
			return true
		current = current.get_base_script()
	return false


func _load_config_directory(root: String, extension: String) -> void:
	var directory := DirAccess.open(root)
	if directory == null:
		return
	var paths: PackedStringArray = PackedStringArray()
	for file_name in directory.get_files():
		var path := root.path_join(String(file_name))
		if path.get_extension().to_lower() != extension:
			continue
		if _parser_for(path) == null:
			continue
		paths.append(path)
	paths.sort()
	# Ascending names, each inserted at index 0. The last name wins.
	for path in paths:
		load_properties(path)


func load_properties(path: String) -> void:
	var parser := _parser_for(path)
	if parser == null:
		push_error("IOC: no property parser for %s." % path)
		return
	var source := parser.parse(path)
	if source == null:
		return
	environment.add_first(source)


func _parser_for(path: String) -> PropertySourceParser:
	for parser in parsers:
		var candidate := parser as PropertySourceParser
		if candidate != null and candidate.handles(path):
			return candidate
	return null


func discover() -> void:
	_scripts.clear()
	_property_roots.clear()
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("language", "")) != "GDScript":
			continue
		var script := load(String(entry.get("path", ""))) as GDScript
		if script == null:
			continue
		_scripts[String(entry.get("class", ""))] = script
	for global_name in _scripts:
		_scan(_scripts[global_name])
	_bind_scanned_properties()


func configuration(script: GDScript) -> Object:
	return _factories.get(script, null)


func resolve(type: GDScript, qualifiers: Array = [], from_node: Node = null) -> Object:
	if type == null:
		push_error("IOC: resolve needs a script.")
		return null
	var found: Array = selector.select(definitions, type, qualifiers)
	if found.size() != 1:
		_report_selection(type, qualifiers, found)
		return null
	return _instance_of(found[0], from_node)


func _instance_of(definition: ComponentDefinition, from_node: Node = null) -> Object:
	if definition in _creating:
		push_error("IOC: cycle while creating %s." % definition.label)
		return null
	var existing := app_scope.fetch(definition)
	if existing != null:
		return existing
	_creating.append(definition)
	var instance := _construct(definition, from_node)
	if instance != null and not _inject_fields(instance, definition, from_node):
		instance = null
	if instance != null:
		app_scope.store(definition, instance)
		app_scope.attach(instance)
	_creating.erase(definition)
	return instance


func _resolve_dependency(dependency: Dictionary, from_node: Node) -> Variant:
	if dependency.get("collection", false):
		return _resolve_all(dependency["type"], dependency["qualifiers"], from_node)
	return resolve(dependency["type"], dependency["qualifiers"], from_node)


func _resolve_all(type: GDScript, qualifiers: Array, from_node: Node) -> Array:
	var found: Array = selector.select(definitions, type, qualifiers)
	var result: Array = []
	for definition in found:
		var instance := _instance_of(definition, from_node)
		if instance == null:
			_collection_failed = true
			return []
		result.append(instance)
	return _typed_array(type, result)


func _typed_array(element: GDScript, values: Array) -> Array:
	# class_name must be the native base. The script carries Enemy, so a
	# subclass such as Dragon is accepted.
	return Array(values, TYPE_OBJECT, element.get_instance_base_type(), element)


func _on_node_added(node: Node) -> void:
	var script := node.get_script() as GDScript
	if script == null:
		return
	var product := _class_product(script)
	if product != null:
		if app_scope.fetch(product) == node:
			return
		push_error("IOC: %s is in a scene and is also @Component. The container would create a second instance." % _script_name(script))
		return
	var fields = _fields(script)
	if fields == null or fields.is_empty():
		return
	_inject_field_list(node, fields, "%s scene" % node.name, node)


func _class_product(script: GDScript) -> ComponentDefinition:
	for definition in definitions:
		var product := definition as ComponentDefinition
		if product != null and product.factory == null and product.type == script:
			return product
	return null


func _scan(script: GDScript) -> void:
	if AnnotationUtils.has_annotation(script, Configuration):
		_register_configuration(script)
		return
	if AnnotationUtils.has_annotation(script, Component):
		_register_class_product(script)
		return
	_reject_orphan_methods(script)


func _register_configuration(script: GDScript) -> void:
	if not _conditions_match(script, "script"):
		return
	if not script.can_instantiate():
		push_error("IOC: configuration %s cannot be constructed." % _script_name(script))
		return
	var factory: Object = script.callv(&"new", [])
	if factory == null:
		push_error("IOC: configuration %s produced null." % _script_name(script))
		return
	_factories[script] = factory
	_collect_property_roots(script)
	var bucket := {"script": script, "factory": factory}
	AnnotationUtils.for_each_annotation_initialized(Component, script, _take_configuration_component.bind(bucket))


func _collect_property_roots(script: GDScript) -> void:
	var bucket := {"script": script}
	AnnotationUtils.for_each_annotation_initialized(ConfigurationPropertiesScan, script, _take_property_root.bind(bucket))


func _take_property_root(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	if not (target is ScriptInfo):
		push_error("IOC: @ConfigurationPropertiesScan on %s belongs on the class." % _script_name(script))
		return
	var root := String(annotation.get("root")).strip_edges().trim_suffix("/")
	if root.is_empty():
		push_error("IOC: %s scan needs a root." % _script_name(script))
		return
	_property_roots.append(root)


func _bind_scanned_properties() -> void:
	if _property_roots.is_empty():
		return
	for global_name in _scripts:
		var script := _scripts[global_name] as GDScript
		if script == null or not AnnotationUtils.has_annotation(script, ConfigurationProperties):
			continue
		if not _under_property_root(script):
			continue
		_register_property_product(script)


func _under_property_root(script: GDScript) -> bool:
	var path := script.resource_path
	for root in _property_roots:
		var prefix := String(root)
		if path == prefix or path.begins_with(prefix + "/"):
			return true
	return false


func _register_property_product(script: GDScript) -> void:
	if not _conditions_match(script, "script"):
		return
	if _class_product(script) != null:
		push_error("IOC: %s is @Component and @ConfigurationProperties." % _script_name(script))
		return
	if not script.can_instantiate():
		push_error("IOC: %s properties cannot be constructed." % _script_name(script))
		return
	var prefix := _property_prefix(script)
	if prefix.is_empty():
		return
	var instance: Object = script.callv(&"new", [])
	if instance == null:
		push_error("IOC: %s properties produced null." % _script_name(script))
		return
	if not binder.bind(instance, prefix, environment):
		return
	_add_definition(script, [], _script_name(script), script, null, &"", [], [])
	var definition := definitions[definitions.size() - 1] as ComponentDefinition
	app_scope.store(definition, instance)
	app_scope.attach(instance)


func _property_prefix(script: GDScript) -> String:
	var bucket := {"script": script, "prefix": "", "found": false, "bad": false}
	AnnotationUtils.for_each_annotation_initialized(ConfigurationProperties, script, _take_property_prefix.bind(bucket))
	if bucket["bad"] or not bucket["found"]:
		return ""
	var prefix := String(bucket["prefix"]).strip_edges().trim_suffix("/")
	if prefix.is_empty():
		push_error("IOC: %s needs a property prefix." % _script_name(script))
		return ""
	return prefix


func _take_property_prefix(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	if not (target is ScriptInfo):
		push_error("IOC: @ConfigurationProperties on %s belongs on the class." % _script_name(script))
		bucket["bad"] = true
		return
	bucket["prefix"] = String(annotation.get("prefix"))
	bucket["found"] = true


func _take_configuration_component(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	if target is ScriptInfo:
		return
	if target is FunctionInfo:
		var info := target as FunctionInfo
		if info.is_static:
			push_error("IOC: %s.%s is static. Factory methods are called on the configuration instance." % [_script_name(script), info.name])
			return
		if not _conditions_match(script, "func", info.name):
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
	if not _conditions_match(script, "script"):
		return
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


func _conditions_match(script: GDScript, kind: String, member: StringName = &"") -> bool:
	var found: Array = []
	var bucket := {"kind": kind, "member": member, "found": found}
	AnnotationUtils.for_each_annotation_initialized(Condition, script, _take_condition.bind(bucket))
	for annotation in found:
		var condition := annotation as Condition
		if condition == null or not condition.matches(environment):
			return false
	return true


func _take_condition(annotation: Object, target: Object, bucket: Dictionary) -> void:
	if _is_qualifier_target(target, String(bucket["kind"]), bucket["member"], &""):
		bucket["found"].append(annotation)


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
	for argument in _method_args(script, method):
		var argument_name := String(argument.get("name", ""))
		var dependency = _dependency_from_info("%s.%s" % [_script_name(script), method], argument_name, argument, _qualifiers(script, "param", method, StringName(argument_name)))
		if dependency == null:
			return null
		parameters.append(dependency)
	return parameters


func _method_args(script: GDScript, method: StringName) -> Array:
	for info in script.get_script_method_list():
		if StringName(info.get("name", "")) != method:
			continue
		return info.get("args", [])
	return []


func _fields(script: GDScript) -> Variant:
	if _field_cache.has(script):
		return _field_cache[script]
	var fields: Array = []
	var current := script
	while current != null:
		var bucket := {"script": current, "fields": fields, "failed": false}
		AnnotationUtils.for_each_annotation_initialized(Inject, current, _take_field.bind(bucket))
		if bucket["failed"]:
			_field_cache[script] = null
			return null
		current = current.get_base_script()
	_field_cache[script] = fields
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
	var property := _property_info(script, String(info.name))
	var dependency = _dependency_from_info("%s.%s" % [_script_name(script), info.name], String(info.name), property, _qualifiers(script, "var", info.name, &""))
	if dependency == null:
		bucket["failed"] = true
		return
	bucket["fields"].append(dependency)


func _property_info(script: GDScript, property_name: String) -> Dictionary:
	var current := script
	while current != null:
		for property in current.get_script_property_list():
			if String(property.get("name", "")) == property_name:
				return property
		current = current.get_base_script()
	return {}


func _dependency_from_info(label: String, dependency_name: String, info: Dictionary, qualifiers: Array) -> Variant:
	if info.is_empty():
		push_error("IOC: %s has no type." % label)
		return null
	var type_code := int(info.get("type", TYPE_NIL))
	if type_code == TYPE_ARRAY:
		if int(info.get("hint", 0)) != PROPERTY_HINT_ARRAY_TYPE:
			push_error("IOC: %s needs Array[Type], not an untyped Array." % label)
			return null
		var element_name := String(info.get("hint_string", ""))
		var element_script := _scripts.get(element_name) as GDScript
		if element_script == null:
			push_error("IOC: %s element \"%s\" needs a global GDScript type." % [label, element_name])
			return null
		return {
			"name": dependency_name,
			"type": element_script,
			"collection": true,
			"qualifiers": qualifiers,
		}
	var dependency_script := _script_from_type(type_code, StringName(String(info.get("class_name", ""))))
	if dependency_script == null:
		push_error("IOC: %s needs a global GDScript type." % label)
		return null
	return {
		"name": dependency_name,
		"type": dependency_script,
		"collection": false,
		"qualifiers": qualifiers,
	}


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


func _construct(definition: ComponentDefinition, from_node: Node) -> Object:
	var args: Array = []
	for parameter in definition.parameters:
		var value: Variant = _resolve_dependency(parameter, from_node)
		if not _accept_dependency(parameter, value, "argument", definition.label):
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


func _inject_fields(instance: Object, definition: ComponentDefinition, from_node: Node) -> bool:
	return _inject_field_list(instance, definition.fields, definition.label, from_node)


func _inject_field_list(instance: Object, fields: Array, label: String, from_node: Node) -> bool:
	for field in fields:
		var value: Variant = _resolve_dependency(field, from_node)
		if not _accept_dependency(field, value, "field", label):
			return false
		instance.set(StringName(field["name"]), value)
	return true


func _accept_dependency(dependency: Dictionary, value: Variant, kind: String, label: String) -> bool:
	if dependency.get("collection", false):
		if _collection_failed:
			_collection_failed = false
			push_error("IOC: missing %s %s on %s." % [kind, dependency["name"], label])
			return false
		return true
	if value == null:
		push_error("IOC: missing %s %s on %s." % [kind, dependency["name"], label])
		return false
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
