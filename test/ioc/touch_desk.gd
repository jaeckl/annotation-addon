@Component
class_name TouchDesk
extends RefCounted

var seen: Array = []


@EventListener
func on_touch(event: BodyTouched) -> void:
	seen.append(event.body)
