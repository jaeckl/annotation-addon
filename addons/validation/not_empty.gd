class_name NotEmpty
extends Constraint

## Matches when the value is present and not empty. A string, an array, and
## a dictionary use is_empty. Any other value matches when it is not null.
const repeatable := true


func is_valid(candidate: Variant) -> bool:
	if candidate == null:
		return false
	if candidate is String or candidate is Array or candidate is Dictionary or candidate is PackedStringArray or candidate is PackedInt32Array or candidate is PackedFloat32Array or candidate is PackedByteArray or candidate is PackedVector2Array or candidate is PackedVector3Array or candidate is PackedColorArray:
		return not candidate.is_empty()
	return true


func violation_message(_candidate: Variant) -> String:
	return "must not be empty"
