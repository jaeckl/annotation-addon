@SignalListener
@Component
class_name SignalBadShape
extends Node

signal rang(amount: int)

@SignalListener var label: String = ""


@SignalListener
func bare() -> void:
	pass


@SignalListener("nope")
func on_nope() -> void:
	pass


@SignalListener("rang")
func on_rang() -> void:
	pass


@SignalListener("rang")
static func stat(_amount: int) -> void:
	pass


@SignalListener("rang")
func numbered(_amount: int) -> int:
	return 1
