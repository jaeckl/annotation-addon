class_name Max
extends Constraint

## Matches when a number is at most value. Null matches, so NotNull stays a
## separate constraint. The first attribute is value, so @Max(1) is positional.
var value: float = 0.0
const repeatable := true


func is_valid(candidate: Variant) -> bool:
	if candidate == null:
		return true
	if not (candidate is int or candidate is float):
		return false
	return float(candidate) <= value


func violation_message(candidate: Variant) -> String:
	if candidate != null and not (candidate is int or candidate is float):
		return "must be a number"
	return "must be at most %s" % value
