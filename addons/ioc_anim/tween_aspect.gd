@Aspect
@Component
class_name TweenAspect
extends RefCounted

## Plays @TweenPlay recipes when the advised method is called.

var book: TweenBook = TweenBook.new()


@Around(TweenPlay)
func play_tween(join: ProceedingJoinPoint) -> Variant:
	if join == null or join.target == null:
		return null
	if not (join.target is Node):
		push_error("Anim: %s.%s is @TweenPlay and is not a Node." % [_type_name(join.target), join.method])
		return join.proceed()
	var mark := _mark(join.target, join.method)
	if mark == null:
		return join.proceed()
	var node := join.target as Node
	if mark.kill:
		book.kill(node, join.method)
	var host := _host(node, mark.bind)
	if host == null:
		push_error("Anim: %s.%s bind path is missing." % [_type_name(node), join.method])
		return join.proceed()
	if mark.props.is_empty():
		push_error("Anim: %s.%s @TweenPlay needs props." % [_type_name(node), join.method])
		return join.proceed()
	if mark.duration < 0.0:
		push_error("Anim: %s.%s @TweenPlay duration must be >= 0." % [_type_name(node), join.method])
		return join.proceed()
	var tween := host.create_tween()
	tween.set_trans(mark.trans)
	tween.set_ease(mark.ease)
	tween.set_parallel(mark.parallel)
	for path in mark.props.keys():
		tween.tween_property(host, NodePath(String(path)), mark.props[path], mark.duration)
	book.store(node, join.method, tween)
	return join.proceed()


func _host(node: Node, bind: NodePath) -> Node:
	if bind == null or bind.is_empty():
		return node
	return node.get_node_or_null(bind)


func _mark(target: Object, method: StringName) -> TweenPlay:
	var script := target.get_script() as GDScript
	while script != null:
		var mark: Variant = AnnotationUtils.get_annotation_initialized(script, TweenPlay, method)
		if mark is TweenPlay:
			return mark as TweenPlay
		script = script.get_base_script()
	return null


func _type_name(target: Object) -> String:
	var script := target.get_script() as GDScript if target != null else null
	if script != null:
		var label := String(script.get_global_name())
		if not label.is_empty():
			return label
	return "?"
