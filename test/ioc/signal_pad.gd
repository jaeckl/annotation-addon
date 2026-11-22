@Component
class_name SignalPad
extends Node

var seen: Array = []


func _ready() -> void:
	var box := SignalHitbox.new()
	box.name = "Hitbox"
	add_child(box)


@SignalListener("touched", ^"Hitbox")
func touched(body: Node) -> BodyTouched:
	seen.append(body)
	return BodyTouched.new(body)
