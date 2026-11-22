@ConditionalOnMissingNode(type_name="AbsentMarker")
@Component
class_name SceneHealthListener
extends RefCounted

var heard: int = 0


@EventListener
func on_health(_event: HealthChanged) -> void:
	heard += 1
