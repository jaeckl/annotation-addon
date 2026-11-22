@Component
class_name InputAfter
extends RefCounted

var ran := 0


@UnhandledInput(action="jump", pressed=true)
func on_jump(_event: InputEvent) -> void:
	ran += 1
