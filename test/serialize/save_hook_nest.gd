@Serialize
class_name SaveHookNest
extends RefCounted

@Serialize var child: SaveHooked
@Transient var after_read_runs := 0


@OnAfterDeserialization
func note_after() -> void:
	after_read_runs += 1
