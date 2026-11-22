@Component
class_name SignalWoven
extends Node

signal rang(amount: int)


@Logged
@SignalListener("rang")
func on_rang(_amount: int) -> void:
	pass
