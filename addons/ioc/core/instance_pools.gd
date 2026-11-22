class_name InstancePools
extends RefCounted

## App product the container registers. borrow returns a parked instance for
## the parent's scene, or builds one. release parks it again. A Node is
## parented under the caller. A RefCounted waits in a list.
var container: IOCContainer


func borrow(type: GDScript, parent: Node) -> Object:
	if container == null:
		push_error("IOC: borrow has no container.")
		return null
	return container.borrow_pooled(type, parent)


func release(instance: Object) -> void:
	if container == null:
		push_error("IOC: release has no container.")
		return
	container.release_pooled(instance)
