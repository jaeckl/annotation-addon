@Aspect
@Component
class_name CooldownAspect
extends RefCounted

## Gates methods marked @Cooldown or @OncePer. Skip returns null.

@Inject var book: CooldownBook


@Around(Cooldown)
func gate_cooldown(join: ProceedingJoinPoint) -> Variant:
	if book == null or join == null or join.target == null:
		return null
	var spec := _cooldown_spec(join.target, join.method)
	if spec == null:
		return null
	if not book.cooldown_open(join.target, join.method, spec):
		return null
	var result: Variant = join.proceed()
	book.arm_cooldown(join.target, join.method, spec)
	return result


@Around(OncePer)
func gate_once(join: ProceedingJoinPoint) -> Variant:
	if book == null or join == null or join.target == null:
		return null
	var physics := _once_physics(join.target, join.method)
	if physics == null:
		return null
	if not book.once_open(join.target, join.method, bool(physics)):
		return null
	book.arm_once(join.target, join.method, bool(physics))
	return join.proceed()


func _cooldown_spec(target: Object, method: StringName) -> ScheduleSpec:
	var mark := _annotation(target, Cooldown, method)
	if mark == null:
		return null
	var text := String(mark.get("value")).strip_edges()
	var spec := ScheduleSpec.parse(text)
	if not spec.error.is_empty() or spec.kind == ScheduleSpec.CRON:
		return null
	return spec


func _once_physics(target: Object, method: StringName) -> Variant:
	var mark := _annotation(target, OncePer, method)
	if mark == null:
		return null
	var text := String(mark.get("value")).strip_edges().to_lower()
	if text == "frame":
		return false
	if text == "physics_frame":
		return true
	return null


func _annotation(target: Object, type: GDScript, method: StringName) -> Object:
	var script := target.get_script() as GDScript
	while script != null:
		var mark: Variant = AnnotationUtils.get_annotation_initialized(script, type, method)
		if mark is Object:
			return mark as Object
		script = script.get_base_script()
	return null
