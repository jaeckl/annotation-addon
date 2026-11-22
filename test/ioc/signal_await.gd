@Component
class_name SignalAwait
extends Node

signal rang
signal go


@SignalListener("rang")
func on_rang() -> void:
	await go
