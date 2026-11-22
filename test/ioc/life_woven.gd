@Component
class_name LifeWoven
extends RefCounted

var ran := 0


@Logged
@Ready
func boot() -> void:
	ran += 1
