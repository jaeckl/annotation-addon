class_name StateMachine
extends GDScriptAnnotation

## Marks an Fsm / FsmObject class. transitions maps each state to an Array of
## allowed next states for try_goto. Empty or omitted means try_goto is open.
var transitions: Dictionary = {}
