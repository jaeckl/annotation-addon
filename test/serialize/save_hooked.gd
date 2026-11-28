@Serialize
class_name SaveHooked
extends RefCounted

## before syncs packed view from live count; after rebuilds count from packed.

@Serialize var count: int = 0
@Transient var live: int = 0
var before_runs := 0
var after_runs := 0


@OnBeforeSerialization
func pack_live() -> void:
	before_runs += 1
	count = live


@OnAfterDeserialization
func unpack_live() -> void:
	after_runs += 1
	live = count
