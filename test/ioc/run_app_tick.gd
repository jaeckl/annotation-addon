@Component
class_name RunAppTick
extends RefCounted

@Inject var log: RunLog


@Process
func on_idle(_delta: float) -> void:
	log.lines.append("tick:app")
