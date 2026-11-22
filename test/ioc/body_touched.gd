class_name BodyTouched
extends Event

var body: Node


func _init(who: Node = null) -> void:
	body = who
