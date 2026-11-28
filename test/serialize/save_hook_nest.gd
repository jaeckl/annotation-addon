@Serialize
class_name SaveHookNest
extends RefCounted

@Serialize var child: SaveHooked
var after_runs := 0


@OnAfterDeserialization
func note_child() -> void:
	after_runs += 1
