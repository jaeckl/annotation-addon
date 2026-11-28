class_name TweenBook
extends RefCounted

## Holds live tweens from @TweenPlay so a second call can kill the previous
## one and pool/destroy can stop them.

## instance_id -> method_name -> Tween
var _live: Dictionary = {}


func store(target: Object, method: StringName, tween: Tween) -> void:
	if target == null or tween == null:
		return
	var id := target.get_instance_id()
	var methods: Dictionary = _live.get(id, {})
	methods[method] = tween
	_live[id] = methods
	if not tween.finished.is_connected(_on_finished):
		tween.finished.connect(_on_finished.bind(id, method))
	if target is Node:
		var node := target as Node
		if not node.tree_exiting.is_connected(_on_exit):
			node.tree_exiting.connect(_on_exit.bind(node), CONNECT_ONE_SHOT)


func kill(target: Object, method: StringName) -> void:
	if target == null:
		return
	var id := target.get_instance_id()
	var methods: Dictionary = _live.get(id, {})
	var tween: Variant = methods.get(method, null)
	if tween is Tween and is_instance_valid(tween):
		(tween as Tween).kill()
	methods.erase(method)
	if methods.is_empty():
		_live.erase(id)
	else:
		_live[id] = methods


func forget(instance: Object) -> void:
	if instance == null:
		return
	var id := instance.get_instance_id()
	var methods: Dictionary = _live.get(id, {})
	for method in methods.keys():
		var tween: Variant = methods[method]
		if tween is Tween and is_instance_valid(tween):
			(tween as Tween).kill()
	_live.erase(id)


func _on_finished(id: int, method: StringName) -> void:
	var methods: Dictionary = _live.get(id, {})
	methods.erase(method)
	if methods.is_empty():
		_live.erase(id)
	else:
		_live[id] = methods


func _on_exit(node: Node) -> void:
	forget(node)
