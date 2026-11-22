@Component
class_name SignalArea
extends Area2D

var seen: Array = []


@SignalListener("body_entered")
func on_body(body: Node) -> void:
	seen.append(body)
