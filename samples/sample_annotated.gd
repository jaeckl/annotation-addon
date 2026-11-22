@SampleNote(note={"place": "script", "index": 1})
@SampleNote(note={"place": "script", "index": 2})
extends Node

@SampleNote(note={"place": "field"})
var health := 1

@SampleNote(note={"place": "function"})
func ping() -> void:
	pass

@warning_ignore("unused_parameter")
func greet(@SampleNote(note={"place": "parameter"}) who: String) -> void:
	pass
