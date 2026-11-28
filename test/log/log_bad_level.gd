@Eager
@Component
class_name LogBadLevel
extends RefCounted


@Logged("nope")
func bad() -> void:
	pass
