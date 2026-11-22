@Component
class_name VisitEarly
extends RefCounted

@Inject var book: VisitBook


@OnSceneEnter
func entered(root: Node) -> void:
	book.lines.append("early:%s" % root.name)


@OnSceneExit
func left(root: Node) -> void:
	book.lines.append("early-exit:%s" % root.name)
