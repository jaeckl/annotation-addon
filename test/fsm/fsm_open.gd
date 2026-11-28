class_name FsmOpen
extends Fsm

## No @StateMachine map — try_goto stays unrestricted.

enum Phase { A, B, C }

var ticks: Array = []


func _init() -> void:
	state = Phase.A


@While(Phase.A)
func in_a(delta: float) -> void:
	ticks.append(["a", delta])


@While(Phase.B)
func in_b(delta: float) -> void:
	ticks.append(["b", delta])
