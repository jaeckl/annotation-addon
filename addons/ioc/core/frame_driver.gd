class_name FrameDriver
extends Node

## Turns _process and _physics_process into calls on published products.
## The container parents this node to the tree root. It is not a product.
var container: IOCContainer


func _process(delta: float) -> void:
	if container != null and is_instance_valid(container):
		container.run_process(delta)


func _physics_process(delta: float) -> void:
	if container != null and is_instance_valid(container):
		container.run_physics_process(delta)
