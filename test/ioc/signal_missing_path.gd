@Component
class_name SignalMissingPath
extends Node


@SignalListener("touched", ^"Nope")
func touched(_body: Node) -> void:
	pass
