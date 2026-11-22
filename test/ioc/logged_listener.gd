@Component
class_name LoggedListener
extends RefCounted

var seen := 0


@Logged
@EventListener
func on_ping(event: AopPing) -> void:
	seen += event.value
