@Component
class_name FrameClock
extends RefCounted

var idle: Array = []
var physics: Array = []


@Process
func on_idle(delta: float) -> void:
	idle.append(delta)


@PhysicsProcess
func on_physics(delta: float) -> void:
	physics.append(delta)
