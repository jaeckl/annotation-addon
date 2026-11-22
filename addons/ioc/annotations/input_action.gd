class_name InputAction
extends GDScriptAnnotation

## Polls the held state on the idle frame, before @Process. One action passes
## get_action_strength to a float, or is_action_pressed to a bool. Two actions
## pass get_axis. The first argument is the negative side.
var negative: String = ""
var positive: String = ""
