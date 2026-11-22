@ConditionalOnMissingNode(type_name="AbsentMarker")
@Component
class_name SceneAction
extends RefCounted

var seen: Array = []


@InputAction("aim")
func aim(down: bool) -> void:
	seen.append(down)
