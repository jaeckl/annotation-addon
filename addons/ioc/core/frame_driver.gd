class_name FrameDriver
extends Node

## Turns _process and _physics_process into calls on published products.
## The container parents this node to the tree root. It is not a product.
## @InputAction is polled at the start of _process, then @Scheduled, then @Process.
var container: IOCContainer


func _process(delta: float) -> void:
	if container != null and is_instance_valid(container):
		container.run_input_actions()
		container.run_scheduled(delta)
		container.run_process(delta)


func _physics_process(delta: float) -> void:
	if container != null and is_instance_valid(container):
		container.run_scheduled_physics()
		container.run_physics_process(delta)
