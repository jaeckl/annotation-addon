class_name AppScope
extends ScopeHandler

## One instance for the process. Nodes are parented to the scene-tree root.
## RefCounted products stay in the map. This scope does not read the caller node.
var _tree: SceneTree
var _instances: Dictionary = {}


func setup(tree: SceneTree) -> void:
	_tree = tree


func fetch(definition: ComponentDefinition, _from_node: Node = null) -> Object:
	return _instances.get(definition, null)


func store(definition: ComponentDefinition, instance: Object, _from_node: Node = null) -> void:
	_instances[definition] = instance


func attach(instance: Object, _from_node: Node = null) -> void:
	if _tree == null or _tree.root == null or not (instance is Node):
		return
	var node := instance as Node
	if node.get_parent() != null:
		return
	# Root is often still entering the tree when the first scene resolves a
	# node. A direct add_child fails then. Deferred add still happens after
	# the fields are set, so _ready sees them.
	_tree.root.add_child.call_deferred(node)


func release(_root: Node) -> void:
	pass
