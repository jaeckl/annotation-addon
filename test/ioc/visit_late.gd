@Component
class_name VisitLate
extends RefCounted

@Inject var early: VisitEarly
@Inject var book: VisitBook


@OnSceneEnter
func entered(root: Node) -> void:
	book.lines.append("late:%s" % root.name)


@OnSceneExit
func left(root: Node) -> void:
	book.lines.append("late-exit:%s" % root.name)
