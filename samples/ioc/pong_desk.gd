@Component
class_name PongDesk
extends RefCounted

var heard: int = 0


@EventListener
func on_pong(_event: ScenePong) -> void:
	heard += 1
