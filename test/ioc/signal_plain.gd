@Component
class_name SignalPlain
extends RefCounted

signal rang


@SignalListener("rang")
func on_rang() -> void:
	pass
