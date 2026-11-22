class_name NotNull
extends Constraint

## Matches when the value is not null.
const repeatable := true


func is_valid(candidate: Variant) -> bool:
	return candidate != null


func violation_message(_candidate: Variant) -> String:
	return "must not be null"
