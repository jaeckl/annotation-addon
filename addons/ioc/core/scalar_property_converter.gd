class_name ScalarPropertyConverter
extends PropertyConverter

## Fallback converter. The same type passes through. An int may fill a float.
## A string fills an int, a float, or a bool when the whole text parses.
## "true" and "false" are the only bool spellings. "fast" is left for a
## converter that sits in front of this one.


func handles(target_type: int, value: Variant, _target_class: String = "") -> bool:
	var value_type := typeof(value)
	if value_type == target_type:
		return true
	if target_type == TYPE_FLOAT and value_type == TYPE_INT:
		return true
	if value_type != TYPE_STRING:
		return false
	var text := String(value).strip_edges()
	match target_type:
		TYPE_INT:
			return text.is_valid_int()
		TYPE_FLOAT:
			return text.is_valid_float()
		TYPE_BOOL:
			var lowered := text.to_lower()
			return lowered == "true" or lowered == "false"
		_:
			return false


func convert(target_type: int, value: Variant, _target_class: String = "") -> Variant:
	var value_type := typeof(value)
	if value_type == target_type:
		return value
	if target_type == TYPE_FLOAT and value_type == TYPE_INT:
		return float(value)
	var text := String(value).strip_edges()
	match target_type:
		TYPE_INT:
			return text.to_int()
		TYPE_FLOAT:
			return text.to_float()
		TYPE_BOOL:
			return text.to_lower() == "true"
		_:
			return value
