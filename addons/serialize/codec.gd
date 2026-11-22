class_name Codec
extends RefCounted

## Turns one document into bytes and back. A document is a dictionary of null,
## bool, int, float, string, array, and dictionary. A codec does not walk
## objects and does not open files.


func write(_document: Dictionary) -> PackedByteArray:
	push_error("Serialize: %s does not write." % _type_name())
	return PackedByteArray()


func read(_bytes: PackedByteArray) -> Dictionary:
	push_error("Serialize: %s does not read." % _type_name())
	return {}


func _type_name() -> String:
	var script := get_script() as GDScript
	if script == null:
		return "Codec"
	var global_name := String(script.get_global_name())
	if global_name.is_empty():
		return "Codec"
	return global_name
