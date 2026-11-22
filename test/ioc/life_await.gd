@Component
class_name LifeAwait
extends RefCounted

signal resume
var started := 0


@Ready
func boot() -> void:
	started += 1
	await resume
