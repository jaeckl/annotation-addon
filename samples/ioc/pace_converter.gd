class_name PaceConverter
extends PropertyConverter

## Sample policy. "slow" and "fast" become ints. The scalar converter does
## not parse those words, so this converter has to sit in front of it.
func handles(target_type: int, value: Variant, _target_class: String = "") -> bool:
	if target_type != TYPE_INT or typeof(value) != TYPE_STRING:
		return false
	var text := String(value).strip_edges()
	return text == "slow" or text == "fast"


func convert(_target_type: int, value: Variant, _target_class: String = "") -> Variant:
	return 1 if String(value).strip_edges() == "slow" else 2
