@Component
class_name ActionPad
extends RefCounted

var axis := 99.0
var strength := 99.0
var down := false
var order: Array = []


@InputAction("move_left", "move_right")
func steer(value: float) -> void:
	axis = value
	order.append("steer")


@InputAction("fire")
func fire(value: float) -> void:
	strength = value
	order.append("fire")


@InputAction("aim")
func aim(value: bool) -> void:
	down = value
	order.append("aim")


@Process
func tick(_delta: float) -> void:
	order.append("tick")
