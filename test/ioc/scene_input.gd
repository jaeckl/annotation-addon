@ConditionalOnMissingNode(type_name="AbsentMarker")
@Component
class_name SceneInput
extends RefCounted

var ran := 0


@UnhandledInput
func on_input(_event: InputEvent) -> void:
	ran += 1
