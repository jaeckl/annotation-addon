@StateMachine(transitions = {
	0: [1, 2],
	1: [0, 2],
	2: [0],
})
class_name FsmBrain
extends Fsm

enum Phase { IDLE, RUN, ATTACK }

var ticks: Array = []
var enters: Array = []
var exits: Array = []


func _init() -> void:
	state = Phase.IDLE


@While(Phase.IDLE)
func idle(delta: float) -> void:
	ticks.append(["idle", delta])


@While(Phase.RUN)
func run(delta: float) -> void:
	ticks.append(["run", delta])


@While(Phase.ATTACK)
func attack(delta: float) -> void:
	ticks.append(["attack", delta])


@OnEnter(Phase.ATTACK)
func start_attack() -> void:
	enters.append("attack")


@OnExit(Phase.ATTACK)
func end_attack() -> void:
	exits.append("attack")
