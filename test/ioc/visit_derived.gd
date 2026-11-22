@Component
class_name VisitDerived
extends VisitBase


@OnSceneEnter
func from_derived(_root: Node) -> void:
	log.append("derived")
