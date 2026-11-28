@StateMachine(transitions = {
	0: [1],
	1: [0],
})
@Component
class_name FsmFlow
extends FsmObject

enum Phase { MENU, PLAY }

var ticks: Array = []
var enters: Array = []


func _init() -> void:
	state = Phase.MENU


@Process
func drive(delta: float) -> void:
	tick(delta)


@While(Phase.MENU)
func menu(delta: float) -> void:
	ticks.append(["menu", delta])


@While(Phase.PLAY)
func play(delta: float) -> void:
	ticks.append(["play", delta])


@OnEnter(Phase.PLAY)
func start_play() -> void:
	enters.append("play")
