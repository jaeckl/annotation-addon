@Component
class_name SignalBell
extends Node

signal rang(amount: int)

var seen: Array = []


@SignalListener("rang")
func on_rang(amount: int) -> void:
	seen.append(amount)
