@ConditionalOnMissingNode(type_name="AbsentMarker")
@Component
class_name VisitScene
extends RefCounted

var hits := 0


@OnSceneEnter
func entered(_root: Node) -> void:
	hits += 1


@OnSceneExit
func left(_root: Node) -> void:
	hits += 1
