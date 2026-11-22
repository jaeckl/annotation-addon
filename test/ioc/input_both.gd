@Component
class_name InputBoth
extends RefCounted

var log: Array = []


@UnhandledInput(action="jump")
@UnhandledInput(action="attack", pressed=true)
func on_input(_event: InputEvent) -> void:
	log.append("hit")
