class_name JoinPoint
extends RefCounted

## One call the container is advising. target is the component instance.
## method is the method name. args are the values passed to that call.
## result is set before @After runs. It stays null for @Before.
var target: Object
var method: StringName = &""
var args: Array = []
var result: Variant
