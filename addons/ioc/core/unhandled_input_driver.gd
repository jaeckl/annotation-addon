class_name UnhandledInputDriver
extends Node

## Forwards _unhandled_input to published products. The container parents this
## node to the tree root. It is not a product. It does not implement _input,
## so the GUI still sees the event first.
var container: IOCContainer


func _unhandled_input(event: InputEvent) -> void:
	if container == null or not is_instance_valid(container):
		return
	if container.run_unhandled_input(event):
		get_viewport().set_input_as_handled()
