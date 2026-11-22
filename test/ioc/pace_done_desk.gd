@Component
class_name PaceDoneDesk
extends RefCounted

var done: Array = []


@EventListener
func on_done(event: PaceDone) -> void:
	done.append(event)
