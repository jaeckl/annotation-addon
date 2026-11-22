class_name Sink
extends RefCounted

## Holds the bytes a codec already produced. A sink does not know about documents.


func write(_bytes: PackedByteArray) -> void:
	push_error("Serialize: %s does not write." % _type_name())


func read() -> PackedByteArray:
	push_error("Serialize: %s does not read." % _type_name())
	return PackedByteArray()


func _type_name() -> String:
	var script := get_script() as GDScript
	if script == null:
		return "Sink"
	var global_name := String(script.get_global_name())
	if global_name.is_empty():
		return "Sink"
	return global_name
