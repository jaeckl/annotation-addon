@Component
class_name VisitAwait
extends RefCounted

signal resume
var started := 0


@OnSceneEnter
func entered(_root: Node) -> void:
	started += 1
	await resume
