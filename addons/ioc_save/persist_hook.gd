@Component
class_name PersistHook
extends ContainerHook

## Applies a pending save entry after inject and before @Ready. Nested @Pooled
## documents are borrowed into body_parent (or the current scene).

@Inject var mapper: Mapper
@Inject var pools: InstancePools

var _pending: Dictionary = {}
var _body_parent: Node


func arm(entries: Dictionary, body_parent: Node) -> void:
	_pending = entries.duplicate()
	_body_parent = body_parent


func clear() -> void:
	_pending.clear()
	_body_parent = null


func before_ready(instance: Object) -> void:
	if instance == null or _pending.is_empty():
		return
	var script := _product_script(instance)
	if script == null or not _is_persist(script):
		return
	var label := String(script.get_global_name())
	if label.is_empty() or not _pending.has(label):
		return
	var bytes: PackedByteArray = _pending[label]
	_pending.erase(label)
	var previous := mapper.make_instance
	mapper.make_instance = _make_nested
	var ok := mapper.read_into(instance, bytes)
	mapper.make_instance = previous
	if not ok:
		push_error("Save: %s could not be restored." % label)


func _make_nested(script: GDScript) -> Object:
	if script == null:
		return null
	if _is_pooled(script):
		var parent := _borrow_parent()
		if parent == null:
			push_error("Save: pooled load needs a scene.")
			return null
		return pools.borrow(script, parent)
	return script.new()


func _borrow_parent() -> Node:
	if _in_scene(_body_parent):
		return _body_parent
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.current_scene


func _in_scene(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var current := node
	while current != null:
		if String(current.scene_file_path) != "":
			return true
		current = current.get_parent()
	return false


func _product_script(instance: Object) -> GDScript:
	var script := instance.get_script() as GDScript
	while script != null:
		if not String(script.get_global_name()).is_empty():
			return script
		script = script.get_base_script()
	return instance.get_script() as GDScript


func _is_persist(script: GDScript) -> bool:
	var current := script
	while current != null:
		if AnnotationUtils.has_annotation(current, Persist):
			return true
		current = current.get_base_script()
	return false


func _is_pooled(script: GDScript) -> bool:
	var current := script
	while current != null:
		if AnnotationUtils.has_annotation(current, Pooled):
			return true
		current = current.get_base_script()
	return false
