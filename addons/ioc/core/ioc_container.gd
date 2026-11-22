class_name IOCContainer
extends RefCounted

## App-scope container. Discovers global classes, resolves products, and fills
## @Inject on nodes a scene already created when those nodes enter the tree.
## A product gated by a node condition is kept on the scene root that admitted
## it, and leaves with that root.
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
var _deferred: Array = []
var _registry_products: Array = []
var _applying_deferred := false
var _property_seen: Dictionary = {}
var _scene_pending: Array = []
var _scene_definitions: Dictionary = {}
var _scene_instances: Dictionary = {}
var _definition_scene: Dictionary = {}
var _open_scenes: Dictionary = {}
var _applying_scene := false
var _active_scene_id := 0
var _active_scene_root: Node
var _scene_bucket: Array = []
var _app_listeners: Array = []
var _scene_listeners: Dictionary = {}
var _app_process: Array = []
var _app_physics: Array = []
var _scene_process: Dictionary = {}
var _scene_physics: Dictionary = {}
var _app_schedules: Array = []
var _app_physics_schedules: Array = []
var _scene_schedules: Dictionary = {}
var _scene_physics_schedules: Dictionary = {}
var _frame: FrameDriver
var _app_input: Array = []
var _scene_input: Dictionary = {}
var _app_actions: Array = []
var _scene_actions: Dictionary = {}
var _input_driver: UnhandledInputDriver
var _signal_links: Array = []
var _signal_ready: Array = []
var _publishing: Array = []
var _async_inflight: Dictionary = {}
var _async_jobs: Array = []
var _advice: Array = []
var _proxy_scripts: Dictionary = {}
var _proxy_origin: Dictionary = {}
var _advice_refused: Dictionary = {}
var _pooled: Dictionary = {}
var _pool_free: Dictionary = {}
var _pool_live: Dictionary = {}
var _pool_known: Dictionary = {}
var _pool_limit: Dictionary = {}
var _pool_release: Dictionary = {}
var _pool_moving := false


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
	if not tree.node_removed.is_connected(_on_node_removed):
		tree.node_removed.connect(_on_node_removed)
	_install_frame()
	_install_input()


## Drops the scene-tree signals. A container left connected still injects
## nodes that enter after another container is in use.
func shutdown() -> void:
	if _tree == null:
		return
	_drop_signal_links(-1)
	_pooled.clear()
	_pool_free.clear()
	_pool_live.clear()
	_pool_known.clear()
	_pool_limit.clear()
	_pool_release.clear()
	if _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.disconnect(_on_node_added)
	if _tree.node_removed.is_connected(_on_node_removed):
		_tree.node_removed.disconnect(_on_node_removed)
	_drop_frame()
	_drop_input()
	_tree = null


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
	_deferred.clear()
	_scene_pending.clear()
	_property_seen.clear()
	_applying_deferred = false
	_applying_scene = false
	_advice.clear()
	_proxy_scripts.clear()
	_proxy_origin.clear()
	_advice_refused.clear()
	_pooled.clear()
	_pool_free.clear()
	_pool_live.clear()
	_pool_known.clear()
	_pool_limit.clear()
	_pool_release.clear()
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("language", "")) != "GDScript":
			continue
		var script := load(String(entry.get("path", ""))) as GDScript
		if script == null:
			continue
		_scripts[String(entry.get("class", ""))] = script
	_register_event_publisher()
	_register_instance_pools()
	for global_name in _scripts:
		_scan(_scripts[global_name])
	_bind_scanned_properties()
	_apply_deferred()
	_open_existing_scenes()


func configuration(script: GDScript) -> Object:
	return _factories.get(script, null)


func resolve(type: GDScript, qualifiers: Array = [], from_node: Node = null) -> Object:
	if type == null:
		push_error("IOC: resolve needs a script.")
		return null
	if _pooled.has(type):
		push_error("IOC: %s is pooled. Borrow it." % _script_name(type))
		return null
	var found: Array = selector.select(_visible_definitions(from_node), type, qualifiers)
	if found.size() != 1:
		_report_selection(type, qualifiers, found)
		return null
	return _instance_of(found[0], from_node)


func _instance_of(definition: ComponentDefinition, from_node: Node = null) -> Object:
	if definition in _creating:
		push_error("IOC: cycle while creating %s." % definition.label)
		return null
	var scene_id := int(_definition_scene.get(definition, 0))
	if scene_id != 0:
		var bucket: Dictionary = _scene_instances.get(scene_id, {})
		var cached: Object = bucket.get(definition, null)
		if cached != null:
			return cached
		if from_node == null:
			from_node = _open_scenes.get(scene_id) as Node
	else:
		var existing := app_scope.fetch(definition)
		if existing != null:
			return existing
	_creating.append(definition)
	var instance := _construct(definition, from_node)
	if instance != null and not _inject_fields(instance, definition, from_node):
		if instance is Node and is_instance_valid(instance):
			(instance as Node).free()
		instance = null
	if instance != null:
		_remember(definition, instance)
	_creating.erase(definition)
	return instance


func _resolve_dependency(dependency: Dictionary, from_node: Node) -> Variant:
	if dependency.get("collection", false):
		return _resolve_all(dependency["type"], dependency["qualifiers"], from_node)
	return resolve(dependency["type"], dependency["qualifiers"], from_node)


func _resolve_all(type: GDScript, qualifiers: Array, from_node: Node) -> Array:
	var found: Array = selector.select(_visible_definitions(from_node), type, qualifiers)
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
	if String(node.scene_file_path) != "":
		_open_scene(node)
	var script := node.get_script() as GDScript
	if script == null:
		return
	var origin := _proxy_origin.get(script, script) as GDScript
	if _pooled.has(origin):
		if _pool_known.has(node.get_instance_id()):
			return
		push_error("IOC: %s is in a scene and is also @Pooled. The container would create a second instance." % _script_name(origin))
		return
	var product := _class_product(script)
	if product != null:
		if _known_product(product, node):
			return
		push_error("IOC: %s is in a scene and is also @Component. The container would create a second instance." % _script_name(script))
		return
	var fields = _fields(script)
	if fields == null or fields.is_empty():
		return
	_inject_field_list(node, fields, "%s scene" % node.name, node)


func _on_node_removed(node: Node) -> void:
	var scene_id := node.get_instance_id()
	if not _open_scenes.has(scene_id):
		return
	var leaving: Array = _scene_definitions.get(scene_id, [])
	for definition in leaving:
		_definition_scene.erase(definition)
	_drop_advice(leaving)
	_scene_definitions.erase(scene_id)
	_scene_instances.erase(scene_id)
	_scene_listeners.erase(scene_id)
	_scene_process.erase(scene_id)
	_scene_physics.erase(scene_id)
	_scene_schedules.erase(scene_id)
	_scene_physics_schedules.erase(scene_id)
	_scene_input.erase(scene_id)
	_scene_actions.erase(scene_id)
	_drop_signal_links(scene_id)
	_drop_scene_pool(scene_id)
	_open_scenes.erase(scene_id)
	_cancel_scene_async(scene_id)


func _open_existing_scenes() -> void:
	if _tree == null or _tree.root == null:
		return
	_open_existing(_tree.root)


func _open_existing(node: Node) -> void:
	if String(node.scene_file_path) != "":
		_open_scene(node)
	for child in node.get_children():
		_open_existing(child)


func _open_scene(root: Node) -> void:
	if root == null:
		return
	var scene_id := root.get_instance_id()
	if _open_scenes.has(scene_id):
		return
	var bucket: Array = []
	_open_scenes[scene_id] = root
	_scene_definitions[scene_id] = bucket
	_scene_instances[scene_id] = {}
	_active_scene_id = scene_id
	_active_scene_root = root
	_scene_bucket = bucket
	_registry_products = definitions.duplicate()
	_applying_scene = true
	for item in _scene_pending:
		var script := item.get("script") as GDScript
		if script == null:
			continue
		match String(item.get("kind", "")):
			"class":
				_register_class_product(script)
			"method":
				if _gate(script, "func", item["method"]) != "ready":
					continue
				_register_method(script, item["factory"], item["method"])
			"configuration":
				_register_configuration(script)
			"property":
				_register_property_product(script)
	_applying_scene = false
	_active_scene_root = null
	_active_scene_id = 0
	_scene_bucket = []
	_registry_products = []


func _visible_definitions(from_node: Node) -> Array:
	var merged: Array = definitions.duplicate()
	var root := _scene_root_of(from_node)
	if root == null:
		return merged
	merged.append_array(_scene_definitions.get(root.get_instance_id(), []))
	return merged


func _scene_root_of(node: Node) -> Node:
	if node == null and _tree != null:
		node = _tree.current_scene
	var current := node
	while current != null:
		if String(current.scene_file_path) != "":
			return current
		current = current.get_parent()
	return null


func _newest_definition() -> ComponentDefinition:
	if _applying_scene:
		return _scene_bucket[_scene_bucket.size() - 1]
	return definitions[definitions.size() - 1]


func publish_event(event: Event, from_node: Node = null, ancestors: Array = []) -> void:
	if event == null:
		push_error("IOC: publish needs an Event.")
		return
	var event_script := event.get_script() as GDScript
	if event_script == null or not _is_event(event_script):
		push_error("IOC: publish needs an Event.")
		return
	if ancestors.has(event_script) or _publishing.has(event_script) or int(_async_inflight.get(event_script, 0)) > 0:
		push_error("IOC: publish of %s is already in progress." % _script_name(event_script))
		return
	_publishing.append(event_script)
	var chain := ancestors.duplicate()
	chain.append(event_script)
	_deliver(_app_listeners, event, event_script, from_node, chain)
	if from_node != null and is_instance_valid(from_node):
		var root := _scene_root_of(from_node)
		if root != null:
			_deliver(_scene_listeners.get(root.get_instance_id(), []), event, event_script, from_node, chain)
	_publishing.pop_back()


func _deliver(listeners: Array, event: Event, event_script: GDScript, from_node: Node, chain: Array) -> void:
	for record in listeners:
		var wanted := record.get("type") as GDScript
		if wanted == null:
			continue
		if event_script != wanted and not _extends_script(event_script, wanted):
			continue
		var instance: Object = record.get("instance")
		if instance == null or not is_instance_valid(instance):
			continue
		_accept_return(instance.call(record.get("method"), event), record, from_node, chain)


func _accept_return(result: Variant, record: Dictionary, from_node: Node, chain: Array) -> void:
	if result == null:
		return
	if _is_suspended(result):
		if not bool(record.get("async", false)):
			push_error("IOC: %s.%s returned %s, not an Event." % [_listener_name(record), record.get("method"), type_string(typeof(result))])
			return
		_suspend(result, record, from_node, chain)
		return
	if not (result is Event):
		push_error("IOC: %s.%s returned %s, not an Event." % [_listener_name(record), record.get("method"), type_string(typeof(result))])
		return
	publish_event(result, from_node, chain)


func _is_suspended(result: Variant) -> bool:
	if typeof(result) != TYPE_OBJECT:
		return false
	var obj := result as Object
	return obj != null and obj.get_class() == "GDScriptFunctionState"


func _suspend(state: Object, record: Dictionary, from_node: Node, chain: Array) -> void:
	var script := chain[chain.size() - 1] as GDScript
	var from_id := 0
	if from_node != null and is_instance_valid(from_node):
		from_id = from_node.get_instance_id()
	var job := {
		"done": false,
		"script": script,
		"scene_id": int(record.get("scene_id", 0)),
		"state": state,
	}
	_async_inflight[script] = int(_async_inflight.get(script, 0)) + 1
	_async_jobs.append(job)
	var error := state.connect("completed", _resume_listener.bind(job, record, from_id, chain))
	if error != OK:
		job["done"] = true
		_async_jobs.erase(job)
		_release_async(script)
		push_error("IOC: %s.%s could not suspend." % [_listener_name(record), record.get("method")])


func _resume_listener(value: Variant, job: Dictionary, record: Dictionary, from_id: int, chain: Array) -> void:
	if bool(job.get("done", false)):
		return
	job["done"] = true
	job["state"] = null
	_async_jobs.erase(job)
	_release_async(job.get("script"))
	var scene_id := int(job.get("scene_id", 0))
	if scene_id != 0 and not _open_scenes.has(scene_id):
		return
	var from_node: Node = null
	if from_id != 0 and is_instance_id_valid(from_id):
		from_node = instance_from_id(from_id) as Node
	_accept_return(value, record, from_node, chain)


func _release_async(script: GDScript) -> void:
	var left := int(_async_inflight.get(script, 1)) - 1
	if left <= 0:
		_async_inflight.erase(script)
		return
	_async_inflight[script] = left


func _cancel_scene_async(scene_id: int) -> void:
	for job in _async_jobs:
		if int(job.get("scene_id", 0)) != scene_id or bool(job.get("done", false)):
			continue
		job["done"] = true
		job["state"] = null
		_release_async(job.get("script"))


func _listener_name(record: Dictionary) -> String:
	var instance: Object = record.get("instance")
	if instance == null:
		return "?"
	var script := instance.get_script() as GDScript
	return _script_name(_proxy_origin.get(script, script))


func _register_event_publisher() -> void:
	var script := _scripts.get("EventPublisher") as GDScript
	if script == null:
		push_error("IOC: EventPublisher is missing.")
		return
	var publisher := EventPublisher.new()
	publisher.container = self
	_add_definition(script, [], "EventPublisher", script, null, &"", [], [])
	_remember(_newest_definition(), publisher)


func _register_instance_pools() -> void:
	var script := _scripts.get("InstancePools") as GDScript
	if script == null:
		push_error("IOC: InstancePools is missing.")
		return
	var pools := InstancePools.new()
	pools.container = self
	_add_definition(script, [], "InstancePools", script, null, &"", [], [])
	_remember(_newest_definition(), pools)


func borrow_pooled(type: GDScript, parent: Node) -> Object:
	if type == null:
		push_error("IOC: borrow needs a class.")
		return null
	if parent == null:
		push_error("IOC: borrow needs a parent.")
		return null
	var definition := _pooled.get(type) as ComponentDefinition
	if definition == null:
		push_error("IOC: %s is not pooled." % _script_name(type))
		return null
	var root := _scene_root_of(parent)
	if root == null:
		push_error("IOC: borrow needs a scene.")
		return null
	var scene_id := root.get_instance_id()
	var instance: Object = _take_parked(scene_id, type)
	if instance == null:
		var limit := int(_pool_limit.get(type, 0))
		if limit > 0 and _pool_held(scene_id, type) >= limit:
			push_error("IOC: %s is at its limit of %s." % [_script_name(type), limit])
			return null
		instance = _construct(definition, parent)
		if instance == null:
			return null
		if not _inject_fields(instance, definition, parent):
			if instance is Node and is_instance_valid(instance):
				(instance as Node).free()
			return null
		_watch_pooled(instance, type, scene_id)
	_pool_live[instance.get_instance_id()] = instance
	_place_pooled(instance, parent)
	return instance


func release_pooled(instance: Object) -> void:
	if instance == null or not is_instance_valid(instance):
		push_error("IOC: release needs an instance.")
		return
	var id := instance.get_instance_id()
	if not _pool_live.has(id):
		push_error("IOC: %s is not borrowed." % _pooled_name(instance))
		return
	_pool_live.erase(id)
	var meta: Dictionary = _pool_known.get(id, {})
	var scene_id := int(meta.get("scene_id", -1))
	var script := meta.get("script") as GDScript
	var root := _open_scenes.get(scene_id) as Node
	if root == null or not is_instance_valid(root) or script == null:
		_forget_pooled(instance)
		if instance is Node and is_instance_valid(instance):
			(instance as Node).queue_free()
		return
	_call_on_release(instance, script)
	if not is_instance_valid(instance) or not _pool_known.has(id):
		return
	if instance is Node and (instance as Node).is_queued_for_deletion():
		return
	if instance is Node:
		_park_node(instance as Node, root)
	var waiting := _free_list(scene_id, script)
	waiting.append(instance)


func _pool_held(scene_id: int, script: GDScript) -> int:
	var held := _free_list(scene_id, script).size()
	for id in _pool_live.keys():
		var meta: Dictionary = _pool_known.get(id, {})
		if meta.get("script") != script or int(meta.get("scene_id", -1)) != scene_id:
			continue
		held += 1
	return held


func _call_on_release(instance: Object, script: GDScript) -> void:
	for method_name in _pool_release.get(script, []):
		var result: Variant = instance.call(method_name)
		if _is_suspended(result):
			push_error("IOC: %s.%s cannot await." % [_script_name(script), method_name])


func _take_parked(scene_id: int, script: GDScript) -> Object:
	var waiting := _free_list(scene_id, script)
	while waiting.size() > 0:
		var instance: Object = waiting.pop_back()
		if instance != null and is_instance_valid(instance):
			return instance
	return null


func _place_pooled(instance: Object, parent: Node) -> void:
	if not (instance is Node):
		return
	var node := instance as Node
	if not is_instance_valid(node):
		return
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	if node.get_parent() == parent:
		return
	_pool_moving = true
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	parent.add_child(node)
	_pool_moving = false


func _park_node(node: Node, root: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	var park := _scene_park(root)
	if node.get_parent() == park:
		return
	_pool_moving = true
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	park.add_child(node)
	_pool_moving = false


func _scene_park(root: Node) -> Node:
	var existing := root.get_node_or_null("IocPool")
	if existing != null:
		return existing
	var park := Node.new()
	park.name = "IocPool"
	park.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(park)
	return park


func _free_list(scene_id: int, script: GDScript) -> Array:
	var bucket: Dictionary = _pool_free.get(scene_id, {})
	if not bucket.has(script):
		bucket[script] = []
		_pool_free[scene_id] = bucket
	return bucket[script]


func _watch_pooled(instance: Object, script: GDScript, scene_id: int) -> void:
	var id := instance.get_instance_id()
	_pool_known[id] = {"instance": instance, "script": script, "scene_id": scene_id}
	if instance is Node:
		var node := instance as Node
		if not node.tree_exiting.is_connected(_on_pooled_exit):
			node.tree_exiting.connect(_on_pooled_exit.bind(node))


func _on_pooled_exit(node: Node) -> void:
	if _pool_moving:
		return
	_forget_pooled(node)


func _forget_pooled(instance: Object) -> void:
	if instance == null:
		return
	var id := instance.get_instance_id()
	var meta: Dictionary = _pool_known.get(id, {})
	_pool_known.erase(id)
	_pool_live.erase(id)
	if meta.is_empty():
		return
	var scene_id := int(meta.get("scene_id", -1))
	var script := meta.get("script") as GDScript
	if script == null or not _pool_free.has(scene_id):
		return
	var bucket: Dictionary = _pool_free[scene_id]
	var waiting: Array = bucket.get(script, [])
	waiting.erase(instance)
	bucket[script] = waiting


func _drop_scene_pool(scene_id: int) -> void:
	var drop: Array = []
	for id in _pool_known.keys():
		var meta: Dictionary = _pool_known[id]
		if int(meta.get("scene_id", -1)) != scene_id:
			continue
		drop.append(meta.get("instance"))
	for instance in drop:
		_forget_pooled(instance)
		if instance is Node and is_instance_valid(instance) and not (instance as Node).is_queued_for_deletion():
			(instance as Node).queue_free()
	_pool_free.erase(scene_id)


func _pooled_name(instance: Object) -> String:
	var script := instance.get_script() as GDScript
	if script == null:
		return "?"
	return _script_name(_proxy_origin.get(script, script) as GDScript)


func _remember(definition: ComponentDefinition, instance: Object) -> void:
	var scene_id := int(_definition_scene.get(definition, 0))
	var live := instance.get_script() as GDScript
	var report := not _same_product_script(live, definition.type)
	_store_listeners(instance, scene_id, report)
	_store_ticks(instance, scene_id, report)
	_store_schedules(instance, scene_id, report)
	_store_input(instance, scene_id, report)
	_store_actions(instance, scene_id, report)
	_arm_signals(instance, scene_id, report)
	if scene_id != 0:
		var bucket: Dictionary = _scene_instances.get(scene_id, {})
		bucket[definition] = instance
		_scene_instances[scene_id] = bucket
		_attach_scene(scene_id, instance)
		return
	app_scope.store(definition, instance)
	app_scope.attach(instance)


func _attach_scene(scene_id: int, instance: Object) -> void:
	if not (instance is Node):
		return
	var root := _open_scenes.get(scene_id) as Node
	if root == null or not is_instance_valid(root):
		return
	var node := instance as Node
	if node.get_parent() != null:
		return
	root.add_child.call_deferred(node)


func _store_listeners(instance: Object, scene_id: int, report: bool) -> void:
	var script := instance.get_script() as GDScript
	if script == null:
		return
	for listener in _collect_listeners(script, report):
		var record := {
			"instance": instance,
			"method": listener["method"],
			"type": listener["type"],
			"async": bool(listener.get("async", false)),
			"scene_id": scene_id,
		}
		if scene_id != 0:
			var bucket: Array = _scene_listeners.get(scene_id, [])
			bucket.append(record)
			_scene_listeners[scene_id] = bucket
		else:
			_app_listeners.append(record)


func _collect_listeners(script: GDScript, report: bool) -> Array:
	var found: Array = []
	var current := script
	while current != null:
		var bucket := {"script": current, "found": found, "report": report}
		AnnotationUtils.for_each_annotation_initialized(EventListener, current, _take_listener.bind(bucket))
		current = current.get_base_script()
	return found


func _take_listener(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	var report: bool = bucket["report"]
	if not (target is FunctionInfo):
		if report:
			push_error("IOC: @EventListener on %s belongs on a method." % _script_name(script))
		return
	var info := target as FunctionInfo
	if info.is_static:
		if report:
			push_error("IOC: %s.%s is static and cannot listen." % [_script_name(script), info.name])
		return
	var args := _method_args(script, info.name)
	if args.size() != 1:
		if report:
			push_error("IOC: %s.%s must take one Event." % [_script_name(script), info.name])
		return
	var argument: Dictionary = args[0]
	var event_script := _script_from_type(int(argument.get("type", TYPE_NIL)), StringName(String(argument.get("class_name", ""))))
	if not _is_event(event_script):
		if report:
			push_error("IOC: %s.%s must take an Event." % [_script_name(script), info.name])
		return
	bucket["found"].append({
		"method": info.name,
		"type": event_script,
		"async": AnnotationUtils.has_annotation(script, Async, info.name),
	})


func _reject_configuration_listeners(script: GDScript) -> void:
	var bucket := {"script": script}
	AnnotationUtils.for_each_annotation_initialized(EventListener, script, _take_configuration_listener.bind(bucket))


func _take_configuration_listener(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	if target is FunctionInfo:
		var info := target as FunctionInfo
		push_error("IOC: %s.%s is @EventListener on a configuration. Put it on a component." % [_script_name(script), info.name])
		return
	push_error("IOC: @EventListener on %s belongs on a method." % _script_name(script))


func _install_frame() -> void:
	if _tree == null or _tree.root == null or _frame != null:
		return
	_frame = FrameDriver.new()
	_frame.container = self
	_frame.name = "IocFrameDriver"
	if _tree.root.is_inside_tree():
		_tree.root.add_child(_frame)
	else:
		_tree.root.add_child.call_deferred(_frame)


func _drop_frame() -> void:
	if _frame != null and is_instance_valid(_frame):
		_frame.container = null
		if _frame.get_parent() != null:
			_frame.get_parent().remove_child(_frame)
		_frame.free()
	_frame = null
	_app_process.clear()
	_app_physics.clear()
	_scene_process.clear()
	_scene_physics.clear()
	_app_schedules.clear()
	_app_physics_schedules.clear()
	_scene_schedules.clear()
	_scene_physics_schedules.clear()
	_app_actions.clear()
	_scene_actions.clear()


## Calls every published @Process method. The frame node uses this from
## _process. A direct call uses the same lists.
func run_process(delta: float) -> void:
	_run_ticks(_app_process, _scene_process, delta)


## Calls every published @PhysicsProcess method. The frame node uses this
## from _physics_process.
func run_physics_process(delta: float) -> void:
	_run_ticks(_app_physics, _scene_physics, delta)


## Calls due @Scheduled methods that use idle time, idle frames, or cron.
func run_scheduled(delta: float) -> void:
	_run_schedules(_app_schedules, _scene_schedules, delta)


## Calls due @Scheduled methods that count physics frames.
func run_scheduled_physics() -> void:
	_run_schedules(_app_physics_schedules, _scene_physics_schedules, 0.0)


func _run_ticks(app: Array, scenes: Dictionary, delta: float) -> void:
	var calls: Array = app.duplicate()
	for scene_id in scenes.keys():
		var bucket: Array = scenes.get(scene_id, [])
		calls.append_array(bucket.duplicate())
	for record in calls:
		_call_tick(record, delta)


func _call_tick(record: Dictionary, delta: float) -> void:
	var instance: Object = record.get("instance")
	if instance == null or not is_instance_valid(instance):
		return
	var value: Variant = instance.call(record.get("method"), delta)
	if not _is_suspended(value):
		return
	var script := record.get("script") as GDScript
	push_error("IOC: %s.%s cannot await." % [_script_name(script), record.get("method")])


func _run_schedules(app: Array, scenes: Dictionary, delta: float) -> void:
	var calls: Array = app.duplicate()
	for scene_id in scenes.keys():
		var bucket: Array = scenes.get(scene_id, [])
		calls.append_array(bucket.duplicate())
	var now := Time.get_datetime_dict_from_system()
	var stamp := _schedule_stamp(now)
	for record in calls:
		if _schedule_due(record, delta, now, stamp):
			_call_schedule(record)


func _schedule_due(record: Dictionary, delta: float, now: Dictionary, stamp: int) -> bool:
	var spec := record.get("spec") as ScheduleSpec
	if spec == null:
		return false
	if spec.kind == ScheduleSpec.TIME:
		var elapsed := float(record.get("elapsed", 0.0)) + delta
		if elapsed < spec.period and not is_equal_approx(elapsed, spec.period):
			record["elapsed"] = elapsed
			return false
		record["elapsed"] = fmod(elapsed, spec.period)
		return true
	if spec.kind == ScheduleSpec.CRON:
		if not spec.matches(now):
			return false
		if int(record.get("stamp", -1)) == stamp:
			return false
		record["stamp"] = stamp
		return true
	var count := int(record.get("count", 0)) + 1
	if count < spec.frames:
		record["count"] = count
		return false
	record["count"] = 0
	return true


func _call_schedule(record: Dictionary) -> void:
	var instance: Object = record.get("instance")
	if instance == null or not is_instance_valid(instance):
		return
	var value: Variant = instance.call(record.get("method"))
	if not _is_suspended(value):
		return
	var script := record.get("script") as GDScript
	push_error("IOC: %s.%s cannot await." % [_script_name(script), record.get("method")])


func _schedule_stamp(now: Dictionary) -> int:
	return int(now.get("year", 0)) * 10000000000 + int(now.get("month", 0)) * 100000000 + int(now.get("day", 0)) * 1000000 + int(now.get("hour", 0)) * 10000 + int(now.get("minute", 0)) * 100 + int(now.get("second", 0))


func _store_schedules(instance: Object, scene_id: int, report: bool) -> void:
	var script := instance.get_script() as GDScript
	if script == null:
		return
	for item in _collect_schedules(script, report):
		var spec := item.get("spec") as ScheduleSpec
		var record := {
			"instance": instance,
			"method": item.get("method"),
			"script": item.get("script"),
			"spec": spec,
			"elapsed": 0.0,
			"count": 0,
			"stamp": -1,
		}
		_append_schedule(scene_id, spec != null and spec.kind == ScheduleSpec.PHYSICS_FRAME, record)


func _append_schedule(scene_id: int, physics: bool, record: Dictionary) -> void:
	if scene_id == 0:
		if physics:
			_app_physics_schedules.append(record)
		else:
			_app_schedules.append(record)
		return
	var table: Dictionary = _scene_physics_schedules if physics else _scene_schedules
	var bucket: Array = table.get(scene_id, [])
	bucket.append(record)
	table[scene_id] = bucket


func _collect_schedules(script: GDScript, report: bool) -> Array:
	var found: Array = []
	if script == null:
		return found
	if _is_node_script(script):
		if report:
			_reject_schedules_on_node(script)
		return found
	var current := script
	while current != null:
		var bucket := {"script": current, "found": found, "report": report}
		AnnotationUtils.for_each_annotation_initialized(Scheduled, current, _take_schedule.bind(bucket))
		current = current.get_base_script()
	return found


func _take_schedule(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	var report: bool = bucket["report"]
	if not (target is FunctionInfo):
		if report:
			push_error("IOC: @Scheduled on %s belongs on a method." % _script_name(script))
		return
	var info := target as FunctionInfo
	if info.is_static:
		if report:
			push_error("IOC: %s.%s is static and cannot be scheduled." % [_script_name(script), info.name])
		return
	if _method_args(script, info.name).size() != 0:
		if report:
			push_error("IOC: %s.%s must take nothing." % [_script_name(script), info.name])
		return
	var text := ""
	if annotation != null:
		text = String(annotation.get("value"))
	var spec := ScheduleSpec.parse(text)
	if spec.error != "":
		if report:
			_report_schedule(script, info.name, spec.error)
		return
	bucket["found"].append({
		"method": info.name,
		"script": script,
		"spec": spec,
	})


func _report_schedule(script: GDScript, method: StringName, reason: String) -> void:
	var who := "%s.%s" % [_script_name(script), method]
	match reason:
		"empty":
			push_error("IOC: %s schedule is empty." % who)
		"zero":
			push_error("IOC: %s schedule must be greater than 0." % who)
		"fraction":
			push_error("IOC: %s must be a whole number of frames." % who)
		_:
			push_error("IOC: %s is not a schedule." % who)


func _reject_schedules_on_node(script: GDScript) -> void:
	var current := script
	while current != null:
		var bucket := {"script": current}
		AnnotationUtils.for_each_annotation_initialized(Scheduled, current, _reject_node_schedule.bind(bucket))
		current = current.get_base_script()


func _reject_node_schedule(_annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	if target is FunctionInfo:
		var info := target as FunctionInfo
		push_error("IOC: %s.%s is @Scheduled on a Node." % [_script_name(script), info.name])
		return
	push_error("IOC: @Scheduled on %s belongs on a method." % _script_name(script))


func _reject_configuration_schedules(script: GDScript) -> void:
	var bucket := {"script": script}
	AnnotationUtils.for_each_annotation_initialized(Scheduled, script, _reject_configuration_schedule.bind(bucket))


func _reject_configuration_schedule(_annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	if target is FunctionInfo:
		var info := target as FunctionInfo
		push_error("IOC: %s.%s is @Scheduled on a configuration. Put it on a component." % [_script_name(script), info.name])
		return
	push_error("IOC: @Scheduled on %s belongs on a method." % _script_name(script))


func _store_ticks(instance: Object, scene_id: int, report: bool) -> void:
	var script := instance.get_script() as GDScript
	if script == null:
		return
	for tick in _collect_ticks(script, report):
		_append_tick(scene_id, bool(tick.get("physics", false)), {
			"instance": instance,
			"method": tick.get("method"),
			"script": tick.get("script"),
		})


func _append_tick(scene_id: int, physics: bool, record: Dictionary) -> void:
	if scene_id == 0:
		if physics:
			_app_physics.append(record)
		else:
			_app_process.append(record)
		return
	var table: Dictionary = _scene_physics if physics else _scene_process
	var bucket: Array = table.get(scene_id, [])
	bucket.append(record)
	table[scene_id] = bucket


func _collect_ticks(script: GDScript, report: bool) -> Array:
	var found: Array = []
	if script == null:
		return found
	if _is_node_script(script):
		if report:
			_reject_ticks_on_node(script)
		return found
	var current := script
	while current != null:
		var bucket := {"script": current, "found": found, "report": report}
		AnnotationUtils.for_each_annotation_initialized(Process, current, _take_process_tick.bind(bucket))
		AnnotationUtils.for_each_annotation_initialized(PhysicsProcess, current, _take_physics_tick.bind(bucket))
		current = current.get_base_script()
	return found


func _take_process_tick(annotation: Object, target: Object, bucket: Dictionary) -> void:
	_take_tick(target, bucket, false)


func _take_physics_tick(annotation: Object, target: Object, bucket: Dictionary) -> void:
	_take_tick(target, bucket, true)


func _take_tick(target: Object, bucket: Dictionary, physics: bool) -> void:
	var script := bucket["script"] as GDScript
	var label := "PhysicsProcess" if physics else "Process"
	var report: bool = bucket["report"]
	if not (target is FunctionInfo):
		if report:
			push_error("IOC: @%s on %s belongs on a method." % [label, _script_name(script)])
		return
	var info := target as FunctionInfo
	if info.is_static:
		if report:
			push_error("IOC: %s.%s is static and cannot tick." % [_script_name(script), info.name])
		return
	if not _takes_one_float(script, info.name):
		if report:
			push_error("IOC: %s.%s must take one float." % [_script_name(script), info.name])
		return
	bucket["found"].append({
		"method": info.name,
		"script": script,
		"physics": physics,
	})


func _reject_ticks_on_node(script: GDScript) -> void:
	var current := script
	while current != null:
		var bucket := {"script": current}
		AnnotationUtils.for_each_annotation_initialized(Process, current, _reject_node_tick.bind(bucket, "Process"))
		AnnotationUtils.for_each_annotation_initialized(PhysicsProcess, current, _reject_node_tick.bind(bucket, "PhysicsProcess"))
		current = current.get_base_script()


func _reject_node_tick(annotation: Object, target: Object, bucket: Dictionary, label: String) -> void:
	var script := bucket["script"] as GDScript
	if target is FunctionInfo:
		var info := target as FunctionInfo
		push_error("IOC: %s.%s is @%s on a Node." % [_script_name(script), info.name, label])
		return
	push_error("IOC: @%s on %s belongs on a method." % [label, _script_name(script)])


func _reject_configuration_ticks(script: GDScript) -> void:
	var bucket := {"script": script}
	AnnotationUtils.for_each_annotation_initialized(Process, script, _reject_configuration_tick.bind(bucket, "Process"))
	AnnotationUtils.for_each_annotation_initialized(PhysicsProcess, script, _reject_configuration_tick.bind(bucket, "PhysicsProcess"))


func _reject_configuration_tick(annotation: Object, target: Object, bucket: Dictionary, label: String) -> void:
	var script := bucket["script"] as GDScript
	if target is FunctionInfo:
		var info := target as FunctionInfo
		push_error("IOC: %s.%s is @%s on a configuration. Put it on a component." % [_script_name(script), info.name, label])
		return
	push_error("IOC: @%s on %s belongs on a method." % [label, _script_name(script)])


func _takes_one_float(script: GDScript, method: StringName) -> bool:
	var args := _method_args(script, method)
	if args.size() != 1:
		return false
	return int(args[0].get("type", TYPE_NIL)) == TYPE_FLOAT


func _is_node_script(script: GDScript) -> bool:
	var base := script.get_instance_base_type()
	return base == &"Node" or ClassDB.is_parent_class(base, &"Node")


func _install_input() -> void:
	if _tree == null or _tree.root == null or _input_driver != null:
		return
	_input_driver = UnhandledInputDriver.new()
	_input_driver.container = self
	_input_driver.name = "IocUnhandledInput"
	if _tree.root.is_inside_tree():
		_tree.root.add_child(_input_driver)
	else:
		_tree.root.add_child.call_deferred(_input_driver)


func _drop_input() -> void:
	if _input_driver != null and is_instance_valid(_input_driver):
		_input_driver.container = null
		if _input_driver.get_parent() != null:
			_input_driver.get_parent().remove_child(_input_driver)
		_input_driver.free()
	_input_driver = null
	_app_input.clear()
	_scene_input.clear()


## Calls published @UnhandledInput methods for one leftover event. Returns
## true when a method returns true. The input node then marks the event
## handled.
func run_unhandled_input(event: InputEvent) -> bool:
	if event == null:
		return false
	var calls: Array = _app_input.duplicate()
	for scene_id in _scene_input.keys():
		var bucket: Array = _scene_input.get(scene_id, [])
		calls.append_array(bucket.duplicate())
	for record in calls:
		if not _input_matches(event, record):
			continue
		if _call_input(record, event):
			return true
	return false


func _input_matches(event: InputEvent, record: Dictionary) -> bool:
	var event_type := String(record.get("event_type", ""))
	if event_type != "" and event_type != "InputEvent" and not event.is_class(event_type):
		return false
	var action := StringName(String(record.get("action", "")))
	if action == &"":
		return true
	if bool(record.get("pressed", false)):
		return event.is_action_pressed(action, false)
	if bool(record.get("released", false)):
		return event.is_action_released(action)
	return event.is_action(action)


func _call_input(record: Dictionary, event: InputEvent) -> bool:
	var instance: Object = record.get("instance")
	if instance == null or not is_instance_valid(instance):
		return false
	var value: Variant = instance.call(record.get("method"), event)
	if _is_suspended(value):
		var script := record.get("script") as GDScript
		push_error("IOC: %s.%s cannot await." % [_script_name(script), record.get("method")])
		return false
	if value == null:
		return false
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	var owner := record.get("script") as GDScript
	push_error("IOC: %s.%s must return bool or nothing." % [_script_name(owner), record.get("method")])
	return false


func _store_input(instance: Object, scene_id: int, report: bool) -> void:
	var script := instance.get_script() as GDScript
	if script == null:
		return
	for handler in _collect_input(script, report):
		_append_input(scene_id, {
			"instance": instance,
			"method": handler.get("method"),
			"script": handler.get("script"),
			"action": handler.get("action", ""),
			"pressed": handler.get("pressed", false),
			"released": handler.get("released", false),
			"event_type": handler.get("event_type", ""),
		})


func _append_input(scene_id: int, record: Dictionary) -> void:
	if scene_id == 0:
		_app_input.append(record)
		return
	var bucket: Array = _scene_input.get(scene_id, [])
	bucket.append(record)
	_scene_input[scene_id] = bucket


func _collect_input(script: GDScript, report: bool) -> Array:
	var found: Array = []
	if script == null:
		return found
	if _is_node_script(script):
		if report:
			_reject_input_on_node(script)
		return found
	var current := script
	while current != null:
		var bucket := {"script": current, "found": found, "report": report}
		AnnotationUtils.for_each_annotation_initialized(UnhandledInput, current, _take_input.bind(bucket))
		current = current.get_base_script()
	return found


func _take_input(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	var report: bool = bucket["report"]
	if not (target is FunctionInfo):
		if report:
			push_error("IOC: @UnhandledInput on %s belongs on a method." % _script_name(script))
		return
	var info := target as FunctionInfo
	if info.is_static:
		if report:
			push_error("IOC: %s.%s is static and cannot take input." % [_script_name(script), info.name])
		return
	var event_type := _input_event_type(script, info.name)
	if event_type == "":
		if report:
			push_error("IOC: %s.%s must take one InputEvent." % [_script_name(script), info.name])
		return
	var action := String(annotation.get("action")).strip_edges()
	var pressed := bool(annotation.get("pressed"))
	var released := bool(annotation.get("released"))
	if pressed and released:
		if report:
			push_error("IOC: %s.%s cannot be both pressed and released." % [_script_name(script), info.name])
		return
	if (pressed or released) and action.is_empty():
		if report:
			push_error("IOC: %s.%s needs an action." % [_script_name(script), info.name])
		return
	if not action.is_empty() and not InputMap.has_action(action):
		if report:
			push_error("IOC: %s.%s action \"%s\" is not in the input map." % [_script_name(script), info.name, action])
		return
	bucket["found"].append({
		"method": info.name,
		"script": script,
		"action": action,
		"pressed": pressed,
		"released": released,
		"event_type": event_type,
	})


func _input_event_type(script: GDScript, method: StringName) -> String:
	var args := _method_args(script, method)
	if args.size() != 1:
		return ""
	var argument: Dictionary = args[0]
	if int(argument.get("type", TYPE_NIL)) != TYPE_OBJECT:
		return ""
	var type_name := String(argument.get("class_name", ""))
	if not _is_input_event_type(type_name):
		return ""
	return type_name


func _is_input_event_type(type_name: String) -> bool:
	if type_name == "InputEvent":
		return true
	if type_name.is_empty():
		return false
	if ClassDB.class_exists(type_name) and ClassDB.is_parent_class(type_name, &"InputEvent"):
		return true
	var script := _scripts.get(type_name) as GDScript
	if script == null:
		return false
	var base := String(script.get_instance_base_type())
	return base == "InputEvent" or ClassDB.is_parent_class(base, &"InputEvent")


func _reject_input_on_node(script: GDScript) -> void:
	var current := script
	while current != null:
		var bucket := {"script": current}
		AnnotationUtils.for_each_annotation_initialized(UnhandledInput, current, _reject_node_input.bind(bucket))
		current = current.get_base_script()


func _reject_node_input(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	if target is FunctionInfo:
		var info := target as FunctionInfo
		push_error("IOC: %s.%s is @UnhandledInput on a Node." % [_script_name(script), info.name])
		return
	push_error("IOC: @UnhandledInput on %s belongs on a method." % _script_name(script))


func _reject_configuration_input(script: GDScript) -> void:
	var bucket := {"script": script}
	AnnotationUtils.for_each_annotation_initialized(UnhandledInput, script, _reject_configuration_input_mark.bind(bucket))


func _reject_configuration_input_mark(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	if target is FunctionInfo:
		var info := target as FunctionInfo
		push_error("IOC: %s.%s is @UnhandledInput on a configuration. Put it on a component." % [_script_name(script), info.name])
		return
	push_error("IOC: @UnhandledInput on %s belongs on a method." % _script_name(script))


## Polls every published @InputAction. The frame node calls this at the
## start of _process, before the @Process methods. A direct call uses the
## same lists. The value is the held state, including zero.
func run_input_actions() -> void:
	var calls: Array = _app_actions.duplicate()
	for scene_id in _scene_actions.keys():
		var bucket: Array = _scene_actions.get(scene_id, [])
		calls.append_array(bucket.duplicate())
	for record in calls:
		_call_action(record)


func _call_action(record: Dictionary) -> void:
	var instance: Object = record.get("instance")
	if instance == null or not is_instance_valid(instance):
		return
	var negative := StringName(String(record.get("negative", "")))
	var positive := StringName(String(record.get("positive", "")))
	var value: Variant
	match String(record.get("kind", "")):
		"axis":
			value = Input.get_axis(negative, positive)
		"strength":
			value = Input.get_action_strength(negative)
		_:
			value = Input.is_action_pressed(negative)
	var result: Variant = instance.call(record.get("method"), value)
	if not _is_suspended(result):
		return
	var script := record.get("script") as GDScript
	push_error("IOC: %s.%s cannot await." % [_script_name(script), record.get("method")])


func _store_actions(instance: Object, scene_id: int, report: bool) -> void:
	var script := instance.get_script() as GDScript
	if script == null:
		return
	for action in _collect_actions(script, report):
		_append_action(scene_id, {
			"instance": instance,
			"method": action.get("method"),
			"script": action.get("script"),
			"negative": action.get("negative", ""),
			"positive": action.get("positive", ""),
			"kind": action.get("kind", ""),
		})


func _append_action(scene_id: int, record: Dictionary) -> void:
	if scene_id == 0:
		_app_actions.append(record)
		return
	var bucket: Array = _scene_actions.get(scene_id, [])
	bucket.append(record)
	_scene_actions[scene_id] = bucket


func _collect_actions(script: GDScript, report: bool) -> Array:
	var found: Array = []
	if script == null:
		return found
	if _is_node_script(script):
		if report:
			_reject_actions_on_node(script)
		return found
	var current := script
	while current != null:
		var bucket := {"script": current, "found": found, "report": report}
		AnnotationUtils.for_each_annotation_initialized(InputAction, current, _take_action.bind(bucket))
		current = current.get_base_script()
	return found


func _take_action(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	var report: bool = bucket["report"]
	if not (target is FunctionInfo):
		if report:
			push_error("IOC: @InputAction on %s belongs on a method." % _script_name(script))
		return
	var info := target as FunctionInfo
	if info.is_static:
		if report:
			push_error("IOC: %s.%s is static and cannot poll an action." % [_script_name(script), info.name])
		return
	var parameter := _action_parameter(script, info.name)
	if parameter == "":
		if report:
			push_error("IOC: %s.%s must take one float or bool." % [_script_name(script), info.name])
		return
	var negative := String(annotation.get("negative")).strip_edges()
	var positive := String(annotation.get("positive")).strip_edges()
	if negative.is_empty():
		if report:
			push_error("IOC: %s.%s needs an action." % [_script_name(script), info.name])
		return
	if not positive.is_empty() and parameter != "float":
		if report:
			push_error("IOC: %s.%s axis needs a float." % [_script_name(script), info.name])
		return
	if not InputMap.has_action(negative) or (not positive.is_empty() and not InputMap.has_action(positive)):
		if report:
			var missing := negative if not InputMap.has_action(negative) else positive
			push_error("IOC: %s.%s action \"%s\" is not in the input map." % [_script_name(script), info.name, missing])
		return
	var kind := "axis" if not positive.is_empty() else ("strength" if parameter == "float" else "pressed")
	bucket["found"].append({
		"method": info.name,
		"script": script,
		"negative": negative,
		"positive": positive,
		"kind": kind,
	})


func _action_parameter(script: GDScript, method: StringName) -> String:
	var args := _method_args(script, method)
	if args.size() != 1:
		return ""
	var type_code := int(args[0].get("type", TYPE_NIL))
	if type_code == TYPE_FLOAT:
		return "float"
	if type_code == TYPE_BOOL:
		return "bool"
	return ""


func _reject_actions_on_node(script: GDScript) -> void:
	var current := script
	while current != null:
		var bucket := {"script": current}
		AnnotationUtils.for_each_annotation_initialized(InputAction, current, _reject_node_action.bind(bucket))
		current = current.get_base_script()


func _reject_node_action(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	if target is FunctionInfo:
		var info := target as FunctionInfo
		push_error("IOC: %s.%s is @InputAction on a Node." % [_script_name(script), info.name])
		return
	push_error("IOC: @InputAction on %s belongs on a method." % _script_name(script))


func _reject_configuration_actions(script: GDScript) -> void:
	var bucket := {"script": script}
	AnnotationUtils.for_each_annotation_initialized(InputAction, script, _reject_configuration_action.bind(bucket))


func _reject_configuration_action(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	if target is FunctionInfo:
		var info := target as FunctionInfo
		push_error("IOC: %s.%s is @InputAction on a configuration. Put it on a component." % [_script_name(script), info.name])
		return
	push_error("IOC: @InputAction on %s belongs on a method." % _script_name(script))


## Connects @SignalListener marks on a published Node component. An empty
## path is the component. A path is resolved after _ready, so a child added
## there is present. A returned Event is published with this component as
## the source node.
func _arm_signals(instance: Object, scene_id: int, report: bool) -> void:
	if not (instance is Node):
		return
	var node := instance as Node
	var script := node.get_script() as GDScript
	var records: Array = []
	for mark in _collect_signals(script, report):
		var record: Dictionary = mark.duplicate()
		record["instance"] = node
		records.append(record)
	if records.is_empty():
		return
	if node.is_node_ready():
		for record in records:
			_connect_signal(node, record, scene_id)
		return
	# One watcher for every mark. Bound callables compare equal, so a second
	# ready connection on this node is rejected by the engine.
	var watcher := _connect_ready_signals.bind(node, records, scene_id)
	node.ready.connect(watcher, CONNECT_ONE_SHOT)
	_signal_ready.append({
		"node": node,
		"callable": watcher,
		"scene_id": scene_id,
	})


func _connect_ready_signals(node: Node, records: Array, scene_id: int) -> void:
	for record in records:
		_connect_signal(node, record, scene_id)


func _connect_signal(node: Node, record: Dictionary, scene_id: int) -> void:
	if not is_instance_valid(node):
		return
	var signal_name := StringName(String(record.get("signal_name", "")))
	var path := record.get("path") as NodePath
	var source := node
	if path != null and not path.is_empty():
		source = node.get_node_or_null(path)
		if source == null:
			push_error("IOC: %s.%s path \"%s\" is missing." % [_signal_script_name(record), record.get("method"), path])
			return
	var info := _find_signal(source, signal_name)
	if info.is_empty():
		push_error("IOC: %s.%s signal \"%s\" is missing." % [_signal_script_name(record), record.get("method"), signal_name])
		return
	var signal_args: Array = info.get("args", [])
	var method_args := _method_args(node.get_script(), StringName(String(record.get("method", ""))))
	if not _signal_args_match(method_args, signal_args):
		push_error("IOC: %s.%s must match signal \"%s\"." % [_signal_script_name(record), record.get("method"), signal_name])
		return
	if signal_args.size() > 5:
		push_error("IOC: %s.%s signal \"%s\" has too many arguments." % [_signal_script_name(record), record.get("method"), signal_name])
		return
	var relay := _signal_relay(signal_args.size(), record)
	if source.is_connected(signal_name, relay):
		return
	var error := source.connect(signal_name, relay)
	if error != OK:
		push_error("IOC: %s.%s could not connect \"%s\"." % [_signal_script_name(record), record.get("method"), signal_name])
		return
	_signal_links.append({
		"source": source,
		"signal_name": signal_name,
		"callable": relay,
		"scene_id": scene_id,
	})


func _signal_relay(argc: int, record: Dictionary) -> Callable:
	match argc:
		0:
			return _relay0.bind(record)
		1:
			return _relay1.bind(record)
		2:
			return _relay2.bind(record)
		3:
			return _relay3.bind(record)
		4:
			return _relay4.bind(record)
		_:
			return _relay5.bind(record)


func _relay0(record: Dictionary) -> void:
	_finish_signal([], record)


func _relay1(a: Variant, record: Dictionary) -> void:
	_finish_signal([a], record)


func _relay2(a: Variant, b: Variant, record: Dictionary) -> void:
	_finish_signal([a, b], record)


func _relay3(a: Variant, b: Variant, c: Variant, record: Dictionary) -> void:
	_finish_signal([a, b, c], record)


func _relay4(a: Variant, b: Variant, c: Variant, d: Variant, record: Dictionary) -> void:
	_finish_signal([a, b, c, d], record)


func _relay5(a: Variant, b: Variant, c: Variant, d: Variant, e: Variant, record: Dictionary) -> void:
	_finish_signal([a, b, c, d, e], record)


func _finish_signal(args: Array, record: Dictionary) -> void:
	var instance: Object = record.get("instance")
	if instance == null or not is_instance_valid(instance):
		return
	var result: Variant = instance.callv(StringName(String(record.get("method", ""))), args)
	if _is_suspended(result):
		push_error("IOC: %s.%s cannot await." % [_signal_script_name(record), record.get("method")])
		return
	if result == null:
		return
	if not (result is Event):
		push_error("IOC: %s.%s returned %s, not an Event." % [_signal_script_name(record), record.get("method"), type_string(typeof(result))])
		return
	publish_event(result, instance as Node)


func _drop_signal_links(scene_id: int) -> void:
	var links: Array = []
	for link in _signal_links:
		if scene_id >= 0 and int(link.get("scene_id", 0)) != scene_id:
			links.append(link)
			continue
		var source: Object = link.get("source")
		var callable: Callable = link.get("callable")
		var signal_name := StringName(String(link.get("signal_name", "")))
		if source is Node and is_instance_valid(source) and source.is_connected(signal_name, callable):
			source.disconnect(signal_name, callable)
	var waiting: Array = []
	for link in _signal_ready:
		if scene_id >= 0 and int(link.get("scene_id", 0)) != scene_id:
			waiting.append(link)
			continue
		var node: Object = link.get("node")
		var callable: Callable = link.get("callable")
		if node is Node and is_instance_valid(node) and node.ready.is_connected(callable):
			node.ready.disconnect(callable)
	if scene_id < 0:
		_signal_links.clear()
		_signal_ready.clear()
		return
	_signal_links = links
	_signal_ready = waiting


func _collect_signals(script: GDScript, report: bool) -> Array:
	var found: Array = []
	if script == null:
		return found
	if not _is_node_script(script):
		if report:
			_reject_signals_on_non_node(script)
		return found
	var current := script
	while current != null:
		var bucket := {"script": current, "found": found, "report": report}
		AnnotationUtils.for_each_annotation_initialized(SignalListener, current, _take_signal.bind(bucket))
		current = current.get_base_script()
	return found


func _take_signal(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	var report: bool = bucket["report"]
	if not (target is FunctionInfo):
		if report:
			push_error("IOC: @SignalListener on %s belongs on a method." % _script_name(script))
		return
	var info := target as FunctionInfo
	if info.is_static:
		if report:
			push_error("IOC: %s.%s is static and cannot listen to a signal." % [_script_name(script), info.name])
		return
	var signal_name := String(annotation.get("signal_name")).strip_edges()
	if signal_name.is_empty():
		if report:
			push_error("IOC: %s.%s needs a signal." % [_script_name(script), info.name])
		return
	if not _signal_return_ok(script, info.name):
		if report:
			push_error("IOC: %s.%s must return an Event or nothing." % [_script_name(script), info.name])
		return
	var path := NodePath()
	var raw: Variant = annotation.get("path")
	if raw is NodePath:
		path = raw
	if path.is_empty():
		var signal_info := _find_signal(script, StringName(signal_name))
		if signal_info.is_empty():
			if report:
				push_error("IOC: %s.%s signal \"%s\" is missing." % [_script_name(script), info.name, signal_name])
			return
		if not _signal_args_match(_method_args(script, info.name), signal_info.get("args", [])):
			if report:
				push_error("IOC: %s.%s must match signal \"%s\"." % [_script_name(script), info.name, signal_name])
			return
	bucket["found"].append({
		"method": info.name,
		"signal_name": signal_name,
		"path": path,
		"script": script,
	})


func _reject_signals_on_non_node(script: GDScript) -> void:
	var bucket := {"script": script, "base": String(script.get_instance_base_type())}
	AnnotationUtils.for_each_annotation_initialized(SignalListener, script, _take_non_node_signal.bind(bucket))


func _take_non_node_signal(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	if target is FunctionInfo:
		var info := target as FunctionInfo
		push_error("IOC: %s.%s is @SignalListener on a %s." % [_script_name(script), info.name, bucket.get("base", "?")])
		return
	push_error("IOC: @SignalListener on %s belongs on a method." % _script_name(script))


func _reject_configuration_signals(script: GDScript) -> void:
	var bucket := {"script": script}
	AnnotationUtils.for_each_annotation_initialized(SignalListener, script, _take_configuration_signal.bind(bucket))


func _take_configuration_signal(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	if target is FunctionInfo:
		var info := target as FunctionInfo
		push_error("IOC: %s.%s is @SignalListener on a configuration. Put it on a component." % [_script_name(script), info.name])
		return
	push_error("IOC: @SignalListener on %s belongs on a method." % _script_name(script))


func _reject_loose_signals(script: GDScript) -> void:
	var bucket := {"script": script}
	AnnotationUtils.for_each_annotation_initialized(SignalListener, script, _take_loose_signal.bind(bucket))


func _take_loose_signal(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	if target is FunctionInfo:
		var info := target as FunctionInfo
		push_error("IOC: %s.%s is @SignalListener and %s is not a Node component." % [_script_name(script), info.name, _script_name(script)])
		return
	push_error("IOC: @SignalListener on %s belongs on a method." % _script_name(script))


func _find_signal(owner: Object, signal_name: StringName) -> Dictionary:
	var script: GDScript = null
	var native := &""
	if owner is GDScript:
		script = owner as GDScript
		native = script.get_instance_base_type()
	elif owner is Node:
		var node := owner as Node
		script = node.get_script() as GDScript
		native = StringName(node.get_class())
		if script != null:
			native = script.get_instance_base_type()
	var current := script
	while current != null:
		for info in current.get_script_signal_list():
			if StringName(String(info.get("name", ""))) == signal_name:
				return info
		current = current.get_base_script()
	if native != &"" and ClassDB.class_exists(native) and ClassDB.class_has_signal(native, signal_name):
		return ClassDB.class_get_signal(native, signal_name)
	return {}


func _signal_args_match(method_args: Array, signal_args: Array) -> bool:
	if method_args.size() != signal_args.size():
		return false
	for index in method_args.size():
		if not _signal_arg_accepts(method_args[index], signal_args[index]):
			return false
	return true


func _signal_arg_accepts(method_arg: Dictionary, signal_arg: Dictionary) -> bool:
	var method_type := int(method_arg.get("type", TYPE_NIL))
	if method_type == TYPE_NIL:
		return true
	var signal_type := int(signal_arg.get("type", TYPE_NIL))
	if signal_type == TYPE_NIL:
		return true
	if method_type != signal_type:
		return false
	if method_type != TYPE_OBJECT:
		return true
	var method_class := String(method_arg.get("class_name", ""))
	var signal_class := String(signal_arg.get("class_name", ""))
	if method_class.is_empty() or signal_class.is_empty() or method_class == signal_class:
		return true
	if ClassDB.class_exists(signal_class) and ClassDB.class_exists(method_class):
		return ClassDB.is_parent_class(signal_class, method_class)
	var method_script := _scripts.get(method_class) as GDScript
	var signal_script := _scripts.get(signal_class) as GDScript
	if method_script != null and signal_script != null:
		return signal_script == method_script or _extends_script(signal_script, method_script)
	return false


func _signal_return_ok(script: GDScript, method: StringName) -> bool:
	for info in script.get_script_method_list():
		if StringName(String(info.get("name", ""))) != method:
			continue
		var returned: Dictionary = info.get("return", {})
		var type_code := int(returned.get("type", TYPE_NIL))
		if type_code == TYPE_NIL:
			return true
		if type_code != TYPE_OBJECT:
			return false
		var type_name := String(returned.get("class_name", ""))
		if type_name.is_empty():
			type_name = String(returned.get("hint_string", ""))
		return _is_event(_script_from_type(TYPE_OBJECT, StringName(type_name)))
	return true


func _signal_script_name(record: Dictionary) -> String:
	return _script_name(record.get("script") as GDScript)


func _reject_misplaced_async(script: GDScript) -> void:
	AnnotationUtils.for_each_annotation_initialized(Async, script, _take_async.bind(script))


func _take_async(annotation: Object, target: Object, script: GDScript) -> void:
	if not (target is FunctionInfo):
		push_error("IOC: @Async on %s belongs on a method." % _script_name(script))
		return
	var info := target as FunctionInfo
	if not AnnotationUtils.has_annotation(script, EventListener, info.name):
		push_error("IOC: %s.%s is @Async without @EventListener." % [_script_name(script), info.name])


func _is_event(script: GDScript) -> bool:
	var event_script := _scripts.get("Event") as GDScript
	if script == null or event_script == null:
		return false
	return script == event_script or _extends_script(script, event_script)


func _class_product(script: GDScript) -> ComponentDefinition:
	var origin := _proxy_origin.get(script, script) as GDScript
	for definition in definitions:
		var product := definition as ComponentDefinition
		if product != null and product.factory == null and product.type == origin:
			return product
	return null


func _scan(script: GDScript) -> void:
	_reject_misplaced_async(script)
	_reject_misplaced_advice(script)
	_reject_misplaced_pooled(script)
	_reject_misplaced_release(script)
	_reject_misplaced_scene(script)
	if AnnotationUtils.has_annotation(script, Configuration):
		if AnnotationUtils.has_annotation(script, Pooled):
			push_error("IOC: %s is @Pooled on a configuration." % _script_name(script))
		if AnnotationUtils.has_annotation(script, Scene):
			push_error("IOC: %s is @Scene on a configuration." % _script_name(script))
		_register_configuration(script)
		return
	if AnnotationUtils.has_annotation(script, Component):
		if AnnotationUtils.has_annotation(script, Pooled):
			_register_pooled(script)
			return
		_register_class_product(script)
		return
	if AnnotationUtils.has_annotation(script, Pooled):
		push_error("IOC: %s is @Pooled without @Component." % _script_name(script))
	if AnnotationUtils.has_annotation(script, Scene):
		push_error("IOC: %s is @Scene without @Component." % _script_name(script))
	_reject_orphan_methods(script)
	_reject_loose_signals(script)


func _reject_misplaced_pooled(script: GDScript) -> void:
	AnnotationUtils.for_each_annotation_initialized(Pooled, script, _take_pooled.bind(script))


func _known_product(product: ComponentDefinition, node: Node) -> bool:
	if app_scope.fetch(product) == node:
		return true
	for scene_id in _scene_instances.keys():
		var bucket: Dictionary = _scene_instances[scene_id]
		if bucket.get(product) == node:
			return true
	return false


func _reject_misplaced_scene(script: GDScript) -> void:
	AnnotationUtils.for_each_annotation_initialized(Scene, script, _take_scene_mark.bind(script))


func _take_scene_mark(_annotation: Object, target: Object, script: GDScript) -> void:
	if target is ScriptInfo:
		return
	push_error("IOC: @Scene on %s belongs on a class." % _script_name(script))


func _reject_scene_args(script: GDScript, parameters: Array) -> bool:
	if not AnnotationUtils.has_annotation(script, Scene) or parameters.is_empty():
		return false
	push_error("IOC: %s is a scene and cannot take constructor arguments." % _script_name(script))
	return true


func _scene_pack(script: GDScript) -> Variant:
	if not AnnotationUtils.has_annotation(script, Scene):
		return false
	if not _is_node_script(script):
		push_error("IOC: %s is @Scene and is not a Node." % _script_name(script))
		return null
	var mark: Variant = AnnotationUtils.get_annotation_initialized(script, Scene)
	var path := ""
	if mark is Object:
		path = String(mark.get("path"))
	if path == "":
		push_error("IOC: @Scene on %s needs a path." % _script_name(script))
		return null
	var loaded: Variant = load(path)
	if not (loaded is PackedScene):
		push_error("IOC: %s scene %s did not load." % [_script_name(script), path])
		return null
	var packed := loaded as PackedScene
	if not _same_scene_script(_scene_root_script(packed), script):
		push_error("IOC: %s scene root is not %s." % [_script_name(script), _script_name(script)])
		return null
	return packed


func _scene_root_script(packed: PackedScene) -> GDScript:
	var state := packed.get_state()
	if state == null or state.get_node_count() == 0:
		return null
	for index in state.get_node_property_count(0):
		if state.get_node_property_name(0, index) != &"script":
			continue
		return state.get_node_property_value(0, index) as GDScript
	return null


func _same_scene_script(root_script: GDScript, script: GDScript) -> bool:
	if root_script == null:
		return false
	if root_script == script:
		return true
	var left := root_script.resource_path
	var right := script.resource_path
	return left != "" and left == right


func _take_pooled(_annotation: Object, target: Object, script: GDScript) -> void:
	if target is ScriptInfo:
		return
	push_error("IOC: @Pooled on %s belongs on a class." % _script_name(script))


func _pool_limit_of(script: GDScript) -> int:
	var mark: Variant = AnnotationUtils.get_annotation_initialized(script, Pooled)
	if not (mark is Object):
		return 0
	var limit := int(mark.get("limit"))
	if limit < 0:
		push_error("IOC: %s pool limit must be at least 0." % _script_name(script))
	return limit


func _reject_misplaced_release(script: GDScript) -> void:
	var pooled := AnnotationUtils.has_annotation(script, Pooled)
	AnnotationUtils.for_each_annotation_initialized(OnRelease, script, _take_release_mark.bind(script, pooled))


func _take_release_mark(_annotation: Object, target: Object, script: GDScript, pooled: bool) -> void:
	if not (target is FunctionInfo):
		push_error("IOC: @OnRelease on %s belongs on a method." % _script_name(script))
		return
	if pooled:
		return
	var info := target as FunctionInfo
	push_error("IOC: %s.%s is @OnRelease and %s is not pooled." % [_script_name(script), info.name, _script_name(script)])


func _collect_release(script: GDScript) -> Array:
	var found: Array = []
	var bucket := {"script": script, "found": found}
	AnnotationUtils.for_each_annotation_initialized(OnRelease, script, _take_release_method.bind(bucket))
	return found


func _take_release_method(_annotation: Object, target: Object, bucket: Dictionary) -> void:
	if not (target is FunctionInfo):
		return
	var script := bucket["script"] as GDScript
	var info := target as FunctionInfo
	if info.is_static:
		push_error("IOC: %s.%s is static and cannot reset a pool." % [_script_name(script), info.name])
		return
	if _method_args(script, info.name).size() != 0:
		push_error("IOC: %s.%s must take nothing." % [_script_name(script), info.name])
		return
	bucket["found"].append(info.name)


func _register_pooled(script: GDScript) -> void:
	var decision := _gate(script, "script")
	if decision == "scene":
		push_error("IOC: %s is @Pooled and cannot wait for a scene." % _script_name(script))
		return
	if _postpone(decision, {"kind": "pooled", "script": script}):
		return
	var parameters := _parameters(script, &"_init")
	if parameters == null:
		return
	if _reject_scene_args(script, parameters):
		return
	if not script.can_instantiate():
		push_error("IOC: component %s cannot be constructed." % _script_name(script))
		return
	var fields := _fields(script)
	if fields == null:
		return
	var packed := _scene_pack(script)
	if packed == null:
		return
	_collect_listeners(script, true)
	_collect_ticks(script, true)
	_collect_schedules(script, true)
	_collect_input(script, true)
	_collect_actions(script, true)
	_collect_signals(script, true)
	var limit := _pool_limit_of(script)
	if limit < 0:
		return
	_pool_limit[script] = limit
	_pool_release[script] = _collect_release(script)
	var definition := ComponentDefinition.new()
	definition.type = script
	definition.qualifiers = _qualifiers(script, "script", &"", &"")
	definition.label = _script_name(script)
	definition.owner_script = script
	definition.parameters = parameters
	definition.fields = fields
	if packed is PackedScene:
		definition.packed = packed
	_pooled[script] = definition


func _register_configuration(script: GDScript) -> void:
	var decision := _gate(script, "script")
	if _postpone(decision, {"kind": "configuration", "script": script}):
		return
	if not script.can_instantiate():
		push_error("IOC: configuration %s cannot be constructed." % _script_name(script))
		return
	var factory: Object = script.callv(&"new", [])
	if factory == null:
		push_error("IOC: configuration %s produced null." % _script_name(script))
		return
	_factories[script] = factory
	_reject_configuration_listeners(script)
	_reject_configuration_ticks(script)
	_reject_configuration_schedules(script)
	_reject_configuration_input(script)
	_reject_configuration_actions(script)
	_reject_configuration_signals(script)
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
		if _property_seen.has(script.resource_path):
			continue
		if not _under_property_root(script):
			continue
		_property_seen[script.resource_path] = true
		_register_property_product(script)


func _under_property_root(script: GDScript) -> bool:
	var path := script.resource_path
	for root in _property_roots:
		var prefix := String(root)
		if path == prefix or path.begins_with(prefix + "/"):
			return true
	return false


func _register_property_product(script: GDScript) -> void:
	var decision := _gate(script, "script")
	if _postpone(decision, {"kind": "property", "script": script}):
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
	_collect_ticks(script, true)
	_collect_schedules(script, true)
	_collect_input(script, true)
	_collect_actions(script, true)
	_collect_signals(script, true)
	_add_definition(script, [], _script_name(script), script, null, &"", [], [])
	_remember(_newest_definition(), instance)


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
		var decision := _gate(script, "func", info.name)
		if _postpone(decision, {"kind": "method", "script": script, "factory": bucket["factory"], "method": info.name}):
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
	_collect_listeners(return_script, true)
	_collect_ticks(return_script, true)
	_collect_schedules(return_script, true)
	_collect_input(return_script, true)
	_collect_actions(return_script, true)
	_collect_signals(return_script, true)
	_add_definition(return_script, _qualifiers(script, "func", method, &""), "%s.%s" % [_script_name(script), method], script, factory, method, parameters, fields)


func _register_class_product(script: GDScript) -> void:
	var decision := _gate(script, "script")
	if _postpone(decision, {"kind": "class", "script": script}):
		return
	var parameters := _parameters(script, &"_init")
	if parameters == null:
		return
	if _reject_scene_args(script, parameters):
		return
	if not script.can_instantiate():
		push_error("IOC: component %s cannot be constructed." % _script_name(script))
		return
	var fields := _fields(script)
	if fields == null:
		return
	var packed := _scene_pack(script)
	if packed == null:
		return
	_collect_listeners(script, true)
	_collect_ticks(script, true)
	_collect_schedules(script, true)
	_collect_input(script, true)
	_collect_actions(script, true)
	_collect_signals(script, true)
	_add_definition(script, _qualifiers(script, "script", &"", &""), _script_name(script), script, null, &"", parameters, fields)
	if packed is PackedScene:
		_newest_definition().packed = packed
	_record_advice(script)


func _apply_deferred() -> void:
	# The snapshot is the definitions that do not themselves depend on the
	# registry. Later deferred products stay out of it, so scan order cannot
	# decide, and a default cannot count itself.
	var pending: Array = _deferred.duplicate()
	_deferred.clear()
	_registry_products = definitions.duplicate()
	_applying_deferred = true
	for item in pending:
		var script := item.get("script") as GDScript
		if script == null:
			continue
		match String(item.get("kind", "")):
			"class":
				_register_class_product(script)
			"method":
				if _gate(script, "func", item["method"]) != "ready":
					continue
				_register_method(script, item["factory"], item["method"])
			"configuration":
				_register_configuration(script)
			"property":
				_register_property_product(script)
			"pooled":
				_register_pooled(script)
	# A configuration accepted above may have added a property scan root.
	_bind_scanned_properties()
	_applying_deferred = false
	_registry_products = []


func _gate(script: GDScript, kind: String, member: StringName = &"") -> String:
	var found := _conditions(script, kind, member)
	var reads_registry := false
	var reads_scene := false
	var context := _condition_context()
	for annotation in found:
		var condition := annotation as Condition
		if condition == null:
			return "skip"
		if condition.depends_on_scene():
			reads_scene = true
			continue
		if condition.depends_on_registry():
			reads_registry = true
			continue
		if not condition.matches(context):
			return "skip"
	if reads_scene and not _applying_scene:
		return "scene"
	if reads_registry and not _applying_deferred and not _applying_scene:
		return "defer"
	if reads_registry or reads_scene:
		for annotation in found:
			var condition := annotation as Condition
			if condition == null:
				return "skip"
			if not condition.depends_on_registry() and not condition.depends_on_scene():
				continue
			if not condition.matches(context):
				return "skip"
	return "ready"


func _postpone(decision: String, item: Dictionary) -> bool:
	if decision == "defer":
		_deferred.append(item)
		return true
	if decision == "scene":
		_scene_pending.append(item)
		return true
	return decision == "skip"


func _condition_context() -> ConditionContext:
	var visible: Array = definitions
	if _applying_deferred or _applying_scene:
		visible = _registry_products
	var root: Node = _active_scene_root if _applying_scene else null
	return ConditionContext.new(environment, visible, root)


func _conditions(script: GDScript, kind: String, member: StringName) -> Array:
	var found: Array = []
	var bucket := {"kind": kind, "member": member, "found": found}
	AnnotationUtils.for_each_annotation_initialized(Condition, script, _take_condition.bind(bucket))
	return found


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
	if _applying_scene:
		_scene_bucket.append(definition)
		_definition_scene[definition] = _active_scene_id
	else:
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
	elif definition.packed != null:
		instance = definition.packed.instantiate()
	else:
		instance = _construct_woven(definition, args, from_node)
		if instance == null:
			return null
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


func _construct_woven(definition: ComponentDefinition, args: Array, from_node: Node) -> Object:
	var script := definition.owner_script
	var chains: Dictionary = {}
	if script != null and not AnnotationUtils.has_annotation(script, Aspect):
		var advice_from: Node = from_node if int(_definition_scene.get(definition, 0)) != 0 else null
		var bound: Variant = _bind_advice(script, advice_from)
		if bound == null:
			return null
		chains = bound
		if not chains.is_empty():
			script = _proxy_for(definition.owner_script, chains)
			if script == null:
				return null
	var pushed := false
	if not chains.is_empty():
		AopDispatch.push(script, chains)
		pushed = true
	var instance: Variant = script.callv(&"new", args)
	if pushed:
		AopDispatch.pop(script)
	if instance == null or not (instance is Object):
		push_error("IOC: %s produced null." % definition.label)
		return null
	if not chains.is_empty():
		instance.set(&"__aop_chains", chains)
	return instance


func _bind_advice(type: GDScript, from_node: Node) -> Variant:
	var visible := _visible_advice(from_node)
	if visible.is_empty():
		return {}
	var methods := _declared_methods(type)
	var chains := {}
	for method_name in methods:
		var declared: Dictionary = methods[method_name]
		var info: Dictionary = declared["info"]
		var declaring := declared["script"] as GDScript
		var steps: Array = []
		var refused := false
		for record in visible:
			var pointcut := record.get("pointcut") as GDScript
			if not _exact_pointcut(declaring, pointcut, method_name):
				continue
			if not _advisable(declaring, method_name, info):
				refused = true
				break
			var aspect := _instance_of(record["definition"], from_node)
			if aspect == null:
				return null
			steps.append({
				"kind": record["kind"],
				"method": record["method"],
				"aspect": aspect,
			})
		if refused or steps.is_empty():
			continue
		chains[method_name] = steps
	return chains


func _visible_advice(from_node: Node) -> Array:
	var visible := _visible_definitions(from_node)
	var found: Array = []
	for record in _advice:
		var definition := record.get("definition") as ComponentDefinition
		if definition != null and visible.has(definition):
			found.append(record)
	return found


func _declared_methods(script: GDScript) -> Dictionary:
	# get_script_method_list includes base methods, so it cannot say which
	# script declared one. ReflectionUtils lists each script's own methods
	# and names that script. The first name is the most derived declaration.
	var found := {}
	for item in ReflectionUtils.get_function_list(script):
		var function_info := item as FunctionInfo
		if function_info == null:
			continue
		var method_name := StringName(function_info.name)
		if method_name == &"" or found.has(method_name):
			continue
		var declaring := function_info.get_gdscript()
		found[method_name] = {
			"script": declaring,
			"info": _method_dictionary(declaring, method_name),
		}
	return found


func _method_dictionary(script: GDScript, method_name: StringName) -> Dictionary:
	if script == null:
		return {}
	for info in script.get_script_method_list():
		if StringName(String(info.get("name", ""))) == method_name:
			return info
	return {}


func _exact_pointcut(script: GDScript, pointcut: GDScript, method_name: StringName) -> bool:
	if script == null or pointcut == null:
		return false
	var entry: Variant = AnnotationUtils.get_annotation(script, pointcut, method_name)
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	return String(entry.get("name", "")) == String(pointcut.get_global_name())


func _advisable(script: GDScript, method_name: StringName, info: Dictionary) -> bool:
	var key := "%s.%s" % [_script_name(script), method_name]
	if _advice_refused.has(key):
		return false
	var reason := ""
	var flags := int(info.get("flags", 0))
	var text := String(method_name)
	if method_name == &"_init" or text.begins_with("@") or text.begins_with("__aop_"):
		reason = "cannot be advised"
	elif (flags & METHOD_FLAG_STATIC) != 0:
		reason = "is static and cannot be advised"
	elif (flags & METHOD_FLAG_VARARG) != 0:
		reason = "has a rest argument and cannot be advised"
	elif not AopProxy.defaults_ok(info):
		reason = "defaults cannot be copied onto the proxy"
	if reason.is_empty():
		return true
	_advice_refused[key] = true
	push_error("IOC: %s %s." % [key, reason])
	return false


func _proxy_for(target: GDScript, chains: Dictionary) -> GDScript:
	var names := PackedStringArray()
	for method_name in chains:
		names.append(String(method_name))
	names.sort()
	var key := "%s|%s" % [target.resource_path, "|".join(names)]
	if _proxy_scripts.has(key):
		return _proxy_scripts[key]
	var methods: Array = []
	var declared := _declared_methods(target)
	for method_name in chains:
		methods.append(declared[method_name]["info"])
	var proxy := AopProxy.build(target, methods)
	if proxy == null:
		push_error("IOC: proxy for %s failed to compile." % _script_name(target))
		return null
	_proxy_scripts[key] = proxy
	_proxy_origin[proxy] = target
	return proxy


func _same_product_script(live: GDScript, type: GDScript) -> bool:
	if live == null or type == null:
		return false
	if live == type:
		return true
	return _proxy_origin.get(live, null) == type


func _drop_advice(leaving: Array) -> void:
	if leaving.is_empty():
		return
	var kept: Array = []
	for record in _advice:
		if leaving.has(record.get("definition")):
			continue
		kept.append(record)
	_advice = kept


func _reject_misplaced_advice(script: GDScript) -> void:
	var aspect := AnnotationUtils.has_annotation(script, Aspect)
	var component := AnnotationUtils.has_annotation(script, Component)
	if aspect and not component:
		push_error("IOC: %s is @Aspect without @Component." % _script_name(script))
	if aspect and AnnotationUtils.has_annotation(script, Configuration):
		push_error("IOC: %s is @Aspect on a configuration." % _script_name(script))
	_reject_advice_kind(script, Before, "Before", "JoinPoint", aspect)
	_reject_advice_kind(script, After, "After", "JoinPoint", aspect)
	_reject_advice_kind(script, Around, "Around", "ProceedingJoinPoint", aspect)


func _reject_advice_kind(script: GDScript, kind: GDScript, label: String, expected_name: String, aspect: bool) -> void:
	var bucket := {
		"script": script,
		"label": label,
		"expected": expected_name,
		"aspect": aspect,
	}
	AnnotationUtils.for_each_annotation_initialized(kind, script, _take_advice_placement.bind(bucket))


func _take_advice_placement(annotation: Object, target: Object, bucket: Dictionary) -> void:
	var script := bucket["script"] as GDScript
	var label := String(bucket["label"])
	if not (target is FunctionInfo):
		push_error("IOC: @%s on %s belongs on a method." % [label, _script_name(script)])
		return
	var info := target as FunctionInfo
	if not bool(bucket["aspect"]):
		push_error("IOC: %s.%s is @%s without @Aspect." % [_script_name(script), info.name, label])
		return
	if info.is_static:
		push_error("IOC: %s.%s is static and cannot advise." % [_script_name(script), info.name])
		return
	if not _advice_signature_ok(script, info.name, String(bucket["expected"])):
		push_error("IOC: %s.%s must take one %s." % [_script_name(script), info.name, bucket["expected"]])
		return
	if not _pointcut_ok(annotation.get("pointcut")):
		push_error("IOC: %s.%s pointcut must be an annotation." % [_script_name(script), info.name])


func _record_advice(script: GDScript) -> void:
	if not AnnotationUtils.has_annotation(script, Aspect):
		return
	var definition := _newest_definition()
	for item in ReflectionUtils.get_function_list(script):
		var function_info := item as FunctionInfo
		if function_info == null or function_info.get_gdscript() != script or function_info.is_static:
			continue
		var method_name := StringName(function_info.name)
		_record_kind(script, definition, method_name, Before, "before", "JoinPoint")
		_record_kind(script, definition, method_name, After, "after", "JoinPoint")
		_record_kind(script, definition, method_name, Around, "around", "ProceedingJoinPoint")


func _record_kind(script: GDScript, definition: ComponentDefinition, method_name: StringName, kind: GDScript, kind_name: String, expected_name: String) -> void:
	var entry: Variant = AnnotationUtils.get_annotation(script, kind, method_name)
	if typeof(entry) != TYPE_DICTIONARY:
		return
	if not _advice_signature_ok(script, method_name, expected_name):
		return
	var annotation: Object = AnnotationUtils.instantiate_annotation(entry)
	if annotation == null or not _pointcut_ok(annotation.get("pointcut")):
		return
	_advice.append({
		"definition": definition,
		"kind": kind_name,
		"method": method_name,
		"pointcut": annotation.get("pointcut"),
	})


func _advice_signature_ok(script: GDScript, method_name: StringName, expected_name: String) -> bool:
	var args := _method_args(script, method_name)
	if args.size() != 1:
		return false
	return _parameter_accepts(args[0], _scripts.get(expected_name) as GDScript)


func _parameter_accepts(argument: Dictionary, expected: GDScript) -> bool:
	var type_code := int(argument.get("type", TYPE_NIL))
	if type_code == TYPE_NIL:
		return true
	if type_code != TYPE_OBJECT:
		return false
	var type_name := String(argument.get("class_name", ""))
	if type_name.is_empty() or type_name == "Object":
		return true
	var arg_script := _scripts.get(type_name) as GDScript
	if arg_script == null or expected == null:
		return false
	return arg_script == expected or _extends_script(expected, arg_script)


func _pointcut_ok(pointcut: Variant) -> bool:
	var script := pointcut as GDScript
	if script == null:
		return false
	return script.get_instance_base_type() == &"GDScriptAnnotation"


func _script_name(script: GDScript) -> String:
	if script == null:
		return "?"
	var global_name := String(script.get_global_name())
	if global_name.is_empty():
		return script.resource_path.get_file()
	return global_name
