class_name NonBlank
extends Constraint

## Example constraint. A string must still contain text after trimming.
const repeatable := true


func is_valid(candidate: Variant) -> bool:
	if candidate == null or not (candidate is String):
		return false
	return not String(candidate).strip_edges().is_empty()


func violation_message(_candidate: Variant) -> String:
	return "must contain text"
