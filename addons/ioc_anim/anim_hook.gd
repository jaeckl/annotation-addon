@Component
class_name AnimHook
extends ContainerHook

## Arms @OnAnim connections after the Node is ready. Validates @TweenPlay /
## @OnAnim shapes on publish.


func before_ready(instance: Object) -> void:
	if instance == null:
		return
	var script := instance.get_script() as GDScript
	if script == null:
		return
	_validate(instance, script)
	if not (instance is Node):
		return
	if not _has_on_anim(script):
		return
	var node := instance as Node
	if node.is_node_ready():
		_arm(node)
	else:
		node.ready.connect(_arm.bind(node), CONNECT_ONE_SHOT)


func _validate(instance: Object, script: GDScript) -> void:
	var current := script
	while current != null:
		AnnotationUtils.for_each_annotation_initialized(TweenPlay, current, _check_tween.bind(instance, current))
		AnnotationUtils.for_each_annotation_initialized(OnAnim, current, _check_on_anim.bind(instance, current))
		current = current.get_base_script()


func _check_tween(annotation: Object, target: Object, instance: Object, script: GDScript) -> void:
	if not (target is FunctionInfo):
		push_error("Anim: @TweenPlay on %s belongs on a method." % _type_name(script))
		return
	var info := target as FunctionInfo
	if info.is_static:
		push_error("Anim: %s.%s is static and cannot be @TweenPlay." % [_type_name(script), info.name])
		return
	if not (instance is Node):
		push_error("Anim: %s.%s is @TweenPlay and is not a Node." % [_type_name(script), info.name])
		return
	if annotation is TweenPlay and (annotation as TweenPlay).props.is_empty():
		push_error("Anim: %s.%s @TweenPlay needs props." % [_type_name(script), info.name])


func _check_on_anim(annotation: Object, target: Object, instance: Object, script: GDScript) -> void:
	if not (target is FunctionInfo):
		push_error("Anim: @OnAnim on %s belongs on a method." % _type_name(script))
		return
	var info := target as FunctionInfo
	if info.is_static:
		push_error("Anim: %s.%s is static and cannot be @OnAnim." % [_type_name(script), info.name])
		return
	if not (instance is Node):
		push_error("Anim: %s.%s is @OnAnim and is not a Node." % [_type_name(script), info.name])
		return
	if not (annotation is OnAnim):
		return
	var mark := annotation as OnAnim
	if mark.on_finished == mark.on_started:
		push_error("Anim: %s.%s @OnAnim needs exactly one of on_finished or on_started." % [_type_name(script), info.name])


func _has_on_anim(script: GDScript) -> bool:
	var current := script
	while current != null:
		var found := {"yes": false}
		AnnotationUtils.for_each_annotation_initialized(OnAnim, current, func(_a, _t): found["yes"] = true)
		if bool(found["yes"]):
			return true
		current = current.get_base_script()
	return false


func _arm(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var script := node.get_script() as GDScript
	var current := script
	while current != null:
		AnnotationUtils.for_each_annotation_initialized(OnAnim, current, _connect_mark.bind(node, current))
		current = current.get_base_script()


func _connect_mark(annotation: Object, target: Object, node: Node, script: GDScript) -> void:
	if not (target is FunctionInfo) or not (annotation is OnAnim):
		return
	var info := target as FunctionInfo
	var mark := annotation as OnAnim
	if mark.on_finished == mark.on_started:
		return
	var source: Node = node
	if not mark.player.is_empty():
		source = node.get_node_or_null(mark.player)
		if source == null:
			push_error("Anim: %s.%s player \"%s\" is missing." % [_type_name(script), info.name, mark.player])
			return
	if not (source is AnimationPlayer):
		push_error("Anim: %s.%s player is not an AnimationPlayer." % [_type_name(script), info.name])
		return
	var player := source as AnimationPlayer
	var signal_name := &"animation_finished" if mark.on_finished else &"animation_started"
	var filter := mark.animation.strip_edges()
	var relay := _relay.bind(node, StringName(info.name), filter)
	if player.is_connected(signal_name, relay):
		return
	var error := player.connect(signal_name, relay)
	if error != OK:
		push_error("Anim: %s.%s could not connect %s." % [_type_name(script), info.name, signal_name])


func _relay(anim_name: StringName, node: Node, method: StringName, filter: String) -> void:
	if not is_instance_valid(node):
		return
	if not filter.is_empty() and String(anim_name) != filter:
		return
	node.call(method)


func _type_name(script: GDScript) -> String:
	if script == null:
		return "?"
	var label := String(script.get_global_name())
	if not label.is_empty():
		return label
	return script.resource_path.get_file()
