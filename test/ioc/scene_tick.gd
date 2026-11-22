@ConditionalOnMissingNode(type_name="AbsentMarker")
@Component
class_name SceneTick
extends RefCounted

var seen: Array = []


@Process
func tick(delta: float) -> void:
	seen.append(delta)
