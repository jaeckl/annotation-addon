@Component
class_name FsmHook
extends ContainerHook

## Arms Fsm / FsmObject products after inject and before @Ready. Validates that
## @While / @OnEnter / @OnExit / @StateMachine sit on an Fsm or FsmObject script.


func before_ready(instance: Object) -> void:
	if instance == null:
		return
	var script := instance.get_script() as GDScript
	if script == null:
		return
	var marked := _has_fsm_marks(script)
	var is_fsm := instance is Fsm or instance is FsmObject
	if marked and not is_fsm:
		push_error("FSM: %s has FSM marks and does not extend Fsm or FsmObject." % _type_name(script))
		return
	if not is_fsm:
		return
	if instance.has_method("arm_fsm"):
		instance.call("arm_fsm")


func _has_fsm_marks(script: GDScript) -> bool:
	var found := {"yes": false}
	var current := script
	while current != null:
		if AnnotationUtils.has_annotation(current, StateMachine):
			return true
		AnnotationUtils.for_each_annotation_initialized(While, current, _mark_found.bind(found))
		AnnotationUtils.for_each_annotation_initialized(OnEnter, current, _mark_found.bind(found))
		AnnotationUtils.for_each_annotation_initialized(OnExit, current, _mark_found.bind(found))
		if bool(found["yes"]):
			return true
		current = current.get_base_script()
	return false


func _mark_found(_annotation: Object, _target: Object, found: Dictionary) -> void:
	found["yes"] = true


func _type_name(script: GDScript) -> String:
	if script == null:
		return "?"
	var label := String(script.get_global_name())
	if not label.is_empty():
		return label
	return script.resource_path.get_file()
