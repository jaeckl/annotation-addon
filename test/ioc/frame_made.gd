class_name FrameMade
extends RefCounted

var ticks := 0


@Process
func tick(_delta: float) -> void:
	ticks += 1
