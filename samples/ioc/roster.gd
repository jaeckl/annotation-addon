@Component
class_name Roster
extends RefCounted

## _init parameters are resolved before new().
var clock: GameClock


func _init(@Inject game_clock: GameClock) -> void:
	clock = game_clock
