class_name ContainerHook
extends RefCounted

## A product the container calls around construction. weave may return a
## dictionary of accessors and method source. before_ready runs after inject
## and before @Ready. before_scene_open runs when a scene root opens, before
## scene-scoped products are built. inspect is not used.


func weave(_script: GDScript) -> Variant:
	return null


func before_ready(_instance: Object) -> void:
	pass


func before_scene_open(_root: Node) -> void:
	pass
