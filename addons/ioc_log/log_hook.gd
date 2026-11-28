@Component
class_name LogHook
extends ContainerHook

## Validates @Logged and @Timed shapes on publish.


func before_ready(instance: Object) -> void:
	if instance == null:
		return
	var script := instance.get_script() as GDScript
	if script == null:
		return
	var current := script
	while current != null:
		AnnotationUtils.for_each_annotation_initialized(Logged, current, _check_logged.bind(current))
		AnnotationUtils.for_each_annotation_initialized(Timed, current, _check_timed.bind(current))
		current = current.get_base_script()


func _check_logged(annotation: Object, target: Object, script: GDScript) -> void:
	if not (target is FunctionInfo):
		push_error("Log: @Logged on %s belongs on a method." % _type_name(script))
		return
	var info := target as FunctionInfo
	if info.is_static:
		push_error("Log: %s.%s is static and cannot be @Logged." % [_type_name(script), info.name])
		return
	if not (annotation is Logged):
		return
	var level := String((annotation as Logged).get("value")).strip_edges().to_lower()
	if level.is_empty():
		level = "debug"
	if not _level_ok(level):
		push_error("Log: %s.%s @Logged level must be trace, debug, info, warn, or error." % [
			_type_name(script),
			info.name,
		])


func _check_timed(annotation: Object, target: Object, script: GDScript) -> void:
	if not (target is FunctionInfo):
		push_error("Log: @Timed on %s belongs on a method." % _type_name(script))
		return
	var info := target as FunctionInfo
	if info.is_static:
		push_error("Log: %s.%s is static and cannot be @Timed." % [_type_name(script), info.name])
		return
	if not (annotation is Timed):
		return
	if float((annotation as Timed).get("value")) < 0.0:
		push_error("Log: %s.%s @Timed threshold must be >= 0." % [_type_name(script), info.name])


func _level_ok(level: String) -> bool:
	return level == "trace" or level == "debug" or level == "info" or level == "warn" or level == "error"


func _type_name(script: GDScript) -> String:
	if script == null:
		return "?"
	var label := String(script.get_global_name())
	if not label.is_empty():
		return label
	return script.resource_path.get_file()
