class_name IOCMainLoop
extends SceneTree

## Scene tree for application/run/main_loop_type. Discovery runs after the
## tree exists. Products are created later, on resolve.
var container: IOCContainer


func _initialize() -> void:
	# SceneTree::initialize already built the root, then called this.
	# GDScript cannot call the native virtual, and calling it would recurse.
	container = IOCContainer.new()
	container.setup(self)
	container.discover()


func _finalize() -> void:
	# The tree is still whole here. Scene, run, and app products are destroyed
	# in that order before the root is freed.
	if container != null:
		container.shutdown()
	container = null
