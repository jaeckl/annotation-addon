@Component
class_name InputPad
extends RefCounted

var log: Array = []


@UnhandledInput
func on_any(_event: InputEvent) -> void:
	log.append("any")


@UnhandledInput
func on_key(_event: InputEventKey) -> void:
	log.append("key")


@UnhandledInput(action="jump")
func on_jump(event: InputEvent) -> void:
	log.append("jump:%s" % event.is_pressed())


@UnhandledInput(action="jump", pressed=true)
func on_pressed(_event: InputEvent) -> void:
	log.append("pressed")


@UnhandledInput(action="jump", released=true)
func on_released(_event: InputEvent) -> void:
	log.append("released")
