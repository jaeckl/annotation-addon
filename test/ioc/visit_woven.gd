@Component
class_name VisitWoven
extends RefCounted

var ran := 0


@Logged
@OnSceneEnter
func entered(_root: Node) -> void:
	ran += 1
