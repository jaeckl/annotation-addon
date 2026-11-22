class_name EventPublisher
extends RefCounted

## App product the container registers. Gameplay injects it and publishes
## events. from_node also reaches listeners of that node's scene.
var container: IOCContainer


func publish(event: Event, from_node: Node = null) -> void:
	if event == null:
		push_error("IOC: publish needs an Event.")
		return
	if container == null:
		push_error("IOC: publish has no container.")
		return
	container.publish_event(event, from_node)
