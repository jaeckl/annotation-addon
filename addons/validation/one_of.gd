class_name OneOf
extends Constraint

## Matches when the value equals one entry in values. 1 and 1.0 match.
## Null matches, so NotNull stays a separate constraint.
var values: Array = []
const repeatable := true


func is_valid(candidate: Variant) -> bool:
	if candidate == null:
		return true
	if values.is_empty():
		push_error("Validation: @OneOf needs values.")
		return false
	return values.has(candidate)


func violation_message(_candidate: Variant) -> String:
	if values.is_empty():
		return "needs values"
	return "must be one of " + str(values)
