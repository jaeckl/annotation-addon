class_name MvcGauge
extends Binder

## A custom binder. The constructor listens, and the next line calls from.
var label: Label


func _init(target: Label) -> void:
	label = target
	super()


func _node() -> Node:
	return label


func _show(next: Variant) -> void:
	if is_instance_valid(label):
		label.text = "g:%s" % str(next)
