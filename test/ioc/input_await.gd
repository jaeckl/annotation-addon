@Component
class_name InputAwait
extends RefCounted

signal resume
var started := 0


@UnhandledInput
func on_input(_event: InputEvent) -> void:
	started += 1
	await resume
