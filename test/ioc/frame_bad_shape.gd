@Process
@Component
class_name FrameBadShape
extends RefCounted

@Process var label: String = ""


@Process
func no_args() -> void:
	pass


@Process
func two(_delta: float, _extra: int) -> void:
	pass


@Process
static func stat(_delta: float) -> void:
	pass


@PhysicsProcess
func untyped(_delta) -> void:
	pass
