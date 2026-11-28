class_name SceneScope
extends ScopeHandler

## One instance per sub-scene root. The root is the nearest node with a
## scene_file_path. Node products are parented under that root. RefCounted
## products stay in the map and leave when release runs for that root.
var _roots: Dictionary = {}
var _instances: Dictionary = {}


func open(root: Node) -> void:
	if root == null:
		return
	var scene_id := root.get_instance_id()
	if _roots.has(scene_id):
		return
	_roots[scene_id] = root
	_instances[scene_id] = {}


func has_root(scene_id: int) -> bool:
	return _roots.has(scene_id)


func open_ids() -> Array:
	return _roots.keys()


func root_of(scene_id: int) -> Node:
	return _roots.get(scene_id) as Node


func instances_of(scene_id: int) -> Dictionary:
	return _instances.get(scene_id, {})


func fetch(definition: ComponentDefinition, from_node: Node = null) -> Object:
	return fetch_at(_id_of(from_node), definition)


func store(definition: ComponentDefinition, instance: Object, from_node: Node = null) -> void:
	store_at(_id_of(from_node), definition, instance)


func attach(instance: Object, from_node: Node = null) -> void:
	attach_at(_id_of(from_node), instance)


func release(root: Node) -> void:
	if root == null:
		return
	var scene_id := root.get_instance_id()
	_instances.erase(scene_id)
	_roots.erase(scene_id)


func store_at(scene_id: int, definition: ComponentDefinition, instance: Object) -> void:
	if scene_id == 0:
		return
	var bucket: Dictionary = _instances.get(scene_id, {})
	bucket[definition] = instance
	_instances[scene_id] = bucket


func fetch_at(scene_id: int, definition: ComponentDefinition) -> Object:
	if scene_id == 0:
		return null
	var bucket: Dictionary = _instances.get(scene_id, {})
	return bucket.get(definition, null)


func attach_at(scene_id: int, instance: Object) -> void:
	if scene_id == 0 or not (instance is Node):
		return
	var root := _roots.get(scene_id) as Node
	if root == null or not is_instance_valid(root):
		return
	var node := instance as Node
	if node.get_parent() != null:
		return
	root.add_child.call_deferred(node)


func knows(definition: ComponentDefinition, node: Node) -> bool:
	for scene_id in _instances.keys():
		var bucket: Dictionary = _instances[scene_id]
		if bucket.get(definition) == node:
			return true
	return false


func _id_of(from_node: Node) -> int:
	if from_node == null:
		return 0
	if _roots.has(from_node.get_instance_id()):
		return from_node.get_instance_id()
	var current := from_node
	while current != null:
		var scene_id := current.get_instance_id()
		if _roots.has(scene_id):
			return scene_id
		current = current.get_parent()
	return 0
