@Component
class_name ActionWoven
extends RefCounted

var ran := 0


@Logged
@InputAction("aim")
func aim(_down: bool) -> void:
	ran += 1
