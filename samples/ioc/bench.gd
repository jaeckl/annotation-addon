@Component
class_name Bench
extends RefCounted

## _init receives every Enemy, not one.
var enemies: Array = []


func _init(@Inject pack: Array[Enemy]) -> void:
	enemies = pack
