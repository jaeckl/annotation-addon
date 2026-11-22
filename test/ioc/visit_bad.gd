@OnSceneEnter
@Component
class_name VisitBad
extends RefCounted

@OnSceneEnter var label := ""


@OnSceneExit
static func parked(_root: Node) -> void:
	pass


@OnSceneEnter
func takes() -> void:
	pass


@OnSceneEnter
func named(_label: String) -> void:
	pass


func marked(@OnSceneEnter _root: Node) -> void:
	pass
