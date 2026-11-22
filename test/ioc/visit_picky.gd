@Component
class_name VisitPicky
extends RefCounted

var hits := 0
var names: Array = []


@OnSceneEnter
func entered(root: Node2D) -> void:
	hits += 1
	names.append(root.name)
