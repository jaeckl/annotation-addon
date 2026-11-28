class_name ScopeHandler
extends RefCounted

## Lifetime policy for one kind of product. AppScope and SceneScope are the
## built-ins. The container calls these; it does not keep a second copy of the
## cache rules.


func fetch(_definition: ComponentDefinition, _from_node: Node = null) -> Object:
	return null


func store(_definition: ComponentDefinition, _instance: Object, _from_node: Node = null) -> void:
	pass


func attach(_instance: Object, _from_node: Node = null) -> void:
	pass


func release(_root: Node) -> void:
	pass
