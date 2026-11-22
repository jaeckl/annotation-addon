@InputAction
@Component
class_name ActionBadShape
extends RefCounted

@InputAction var label: String = ""


@InputAction
func no_args() -> void:
	pass


@InputAction("fire")
func two(value: float, _extra: int) -> void:
	pass


@InputAction("fire")
static func stat(_value: float) -> void:
	pass


@InputAction("fire")
func untyped(_value) -> void:
	pass


@InputAction
func empty(value: float) -> void:
	pass


@InputAction("no_such_ioc_action")
func missing(value: float) -> void:
	pass


@InputAction("move_left", "move_right")
func axis_bool(_down: bool) -> void:
	pass
