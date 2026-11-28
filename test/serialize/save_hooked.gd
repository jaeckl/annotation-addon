@Serialize
class_name SaveHooked
extends RefCounted

## before syncs packed view from live count; after rebuilds count from packed.

@Serialize var count: int = 0
@Transient var live: int = 0
@Transient var before_write_runs := 0
@Transient var after_write_runs := 0
@Transient var before_read_runs := 0
@Transient var after_read_runs := 0


@OnBeforeSerialization
func pack_live() -> void:
	before_write_runs += 1
	count = live


@OnAfterSerialization
func note_after_write() -> void:
	after_write_runs += 1


@OnBeforeDeserialization
func note_before_read() -> void:
	before_read_runs += 1


@OnAfterDeserialization
func unpack_live() -> void:
	after_read_runs += 1
	live = count
