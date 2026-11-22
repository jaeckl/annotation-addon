@Component
class_name FrameWoven
extends RefCounted

var ran := 0


@Logged
@Process
func tick(_delta: float) -> void:
	ran += 1
