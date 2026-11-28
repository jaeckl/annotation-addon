@Component
class_name CoolClick
extends RefCounted

var hits := 0


@OncePer("frame")
func tap() -> void:
	hits += 1
