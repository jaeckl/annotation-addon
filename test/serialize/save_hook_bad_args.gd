@Serialize
class_name SaveHookBadArgs
extends RefCounted

var hp := 1


@OnAfterDeserialization
func bad_args(n: int) -> void:
	hp = n
