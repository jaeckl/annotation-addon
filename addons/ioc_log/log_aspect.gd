@Aspect
@Component
class_name LogAspect
extends RefCounted

## Logs @Logged calls and @Timed durations through GameLogger.

@Inject var logger: GameLogger


@Around(Logged)
func log_call(join: ProceedingJoinPoint) -> Variant:
	if join == null or join.target == null:
		return null
	var level := _logged_level(join.target, join.method)
	var result: Variant = join.proceed()
	if logger != null and not level.is_empty():
		logger.log(StringName(level), "%s.%s(%s) -> %s" % [
			_type_name(join.target),
			join.method,
			_args_text(join.args),
			str(result),
		])
	return result


@Around(Timed)
func time_call(join: ProceedingJoinPoint) -> Variant:
	if join == null or join.target == null:
		return null
	var threshold := _timed_threshold(join.target, join.method)
	if threshold < 0.0:
		return join.proceed()
	var started := Time.get_ticks_usec()
	var result: Variant = join.proceed()
	var elapsed_msec := float(Time.get_ticks_usec() - started) / 1000.0
	if logger != null and elapsed_msec >= threshold:
		logger.log(&"info", "%s.%s took %.3f ms" % [
			_type_name(join.target),
			join.method,
			elapsed_msec,
		])
	return result


func _logged_level(target: Object, method: StringName) -> String:
	var mark := _annotation(target, Logged, method)
	if mark == null:
		return ""
	var text := String(mark.get("value")).strip_edges().to_lower()
	if text.is_empty():
		text = "debug"
	if not _level_ok(text):
		return ""
	return text


func _timed_threshold(target: Object, method: StringName) -> float:
	var mark := _annotation(target, Timed, method)
	if mark == null:
		return -1.0
	return float(mark.get("value"))


func _level_ok(level: String) -> bool:
	return level == "trace" or level == "debug" or level == "info" or level == "warn" or level == "error"


func _annotation(target: Object, type: GDScript, method: StringName) -> Object:
	var script := target.get_script() as GDScript
	while script != null:
		var mark: Variant = AnnotationUtils.get_annotation_initialized(script, type, method)
		if mark is Object:
			return mark as Object
		script = script.get_base_script()
	return null


func _args_text(args: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for arg in args:
		parts.append(str(arg))
	return ", ".join(parts)


func _type_name(target: Object) -> String:
	var script := target.get_script() as GDScript if target != null else null
	if script != null:
		var label := String(script.get_global_name())
		if label.is_empty() and script.get_base_script() != null:
			label = String(script.get_base_script().get_global_name())
		if not label.is_empty():
			return label
	return "?"
