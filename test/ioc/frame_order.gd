@Component
class_name FrameOrder
extends RefCounted

var log: Array = []


@Process
func first(_delta: float) -> void:
	log.append("first")


@Process
func second(_delta: float) -> void:
	log.append("second")
