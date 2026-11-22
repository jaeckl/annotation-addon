@Component
class_name FrameLate
extends RefCounted

@Inject var log: FrameLog


@Process
func tick(_delta: float) -> void:
	log.lines.append("late")
