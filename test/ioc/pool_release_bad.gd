@Pooled
@Component
class_name PoolReleaseBad
extends RefCounted


@OnRelease
func clear(_extra: int) -> void:
	pass


@OnRelease
static func parked() -> void:
	pass
