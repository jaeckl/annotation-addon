class_name HealthChanged
extends Event

var current: int = 0


func _init(amount: int = 0) -> void:
	current = amount
