class_name TweenPlay
extends GDScriptAnnotation

## Marks a method on a Node component. Calling the method plays a property
## tween. Named TweenPlay because Tween is an engine class. props maps a
## property path to the target value (for example "modulate:a").
var props: Dictionary = {}
var duration: float = 0.3
var trans: int = Tween.TRANS_LINEAR
var ease: int = Tween.EASE_IN_OUT
var parallel: bool = true
var bind: NodePath = NodePath()
var kill: bool = true
