@Component
class_name FrameAwait
extends RefCounted

signal resume
var started := 0


@Process
func tick(_delta: float) -> void:
	started += 1
	await resume
