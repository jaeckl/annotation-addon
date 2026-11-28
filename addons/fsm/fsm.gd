class_name Fsm
extends Node

## Node state machine. Subclasses call tick from _process. goto is unrestricted;
## try_goto consults @StateMachine(transitions). Same-state goto is a no-op.

var state: Variant = null
var _core: FsmCore = FsmCore.new()


func _ready() -> void:
	arm_fsm()


func arm_fsm() -> void:
	_core.bind(self)


func goto(next: Variant) -> void:
	_core.goto(next)


func try_goto(next: Variant) -> bool:
	return _core.try_goto(next)


func tick(delta: float) -> void:
	_core.tick(delta)
