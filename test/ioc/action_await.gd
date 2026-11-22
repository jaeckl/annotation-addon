@Component
class_name ActionAwait
extends RefCounted

signal resume
var started := 0


@InputAction("aim")
func aim(_down: bool) -> void:
	started += 1
	await resume
