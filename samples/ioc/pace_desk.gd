@Component
class_name PaceDesk
extends RefCounted

var noted: Array = []


@EventListener
func on_noted(event: PaceNoted) -> void:
	noted.append(event)
