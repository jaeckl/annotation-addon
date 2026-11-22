@Component
class_name VisitBase
extends RefCounted

var log: Array = []


@OnSceneEnter
func from_base(_root: Node) -> void:
	log.append("base")
