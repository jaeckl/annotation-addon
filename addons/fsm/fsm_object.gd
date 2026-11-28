class_name FsmObject
extends RefCounted

## RefCounted state machine for IoC products that use @Process. Same API as Fsm.
## Call arm_fsm after construction when _ready will not run.

var state: Variant = null
var _core: FsmCore = FsmCore.new()


func arm_fsm() -> void:
	_core.bind(self)


func goto(next: Variant) -> void:
	_core.goto(next)


func try_goto(next: Variant) -> bool:
	return _core.try_goto(next)


func tick(delta: float) -> void:
	_core.tick(delta)
