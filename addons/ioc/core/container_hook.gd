class_name ContainerHook
extends RefCounted

## A product the container calls around construction. weave may return a
## dictionary of accessors and method source. before_ready runs after inject
## and before @Ready. inspect is not used. The MVC starter is one hook.


func weave(_script: GDScript) -> Variant:
	return null


func before_ready(_instance: Object) -> void:
	pass
