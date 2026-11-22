@Component
class_name Hud
extends Node

## Node product. clock is set before add_child, so _ready can read it.
@Inject var clock: GameClock
var saw_clock := false


func _ready() -> void:
	saw_clock = clock != null and clock.started
