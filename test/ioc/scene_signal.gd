@ConditionalOnMissingNode(type_name="AbsentMarker")
@Component
class_name SceneSignal
extends Node

signal rang

var seen := 0


@SignalListener("rang")
func on_rang() -> void:
	seen += 1
