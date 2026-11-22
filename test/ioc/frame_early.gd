@Component
class_name FrameEarly
extends RefCounted

@Inject var log: FrameLog


@Process
func tick(_delta: float) -> void:
	log.lines.append("early")
