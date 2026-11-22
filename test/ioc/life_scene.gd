@ConditionalOnMissingNode(type_name="AbsentMarker")
@Component
class_name LifeScene
extends RefCounted

var ready_hits := 0
var destroy_hits := 0


@Ready
func boot() -> void:
	ready_hits += 1


@OnDestroy
func down() -> void:
	destroy_hits += 1
