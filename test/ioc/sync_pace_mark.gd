@Component
class_name SyncPaceMark
extends RefCounted

var seen: int = 0


@EventListener
func on_pace(_event: PaceChanged) -> void:
	seen += 1
