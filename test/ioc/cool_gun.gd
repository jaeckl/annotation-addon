@Component
class_name CoolGun
extends RefCounted

var shots: Array = []


@Cooldown("1s")
@Process
func fire(delta: float) -> void:
	shots.append(delta)
