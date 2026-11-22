class_name ValueRange
extends Constraint

## Matches a number inside minimum and maximum, the same idea as
## @export_range. The class is ValueRange because Godot's Range is a
## Control. step 0 allows any value in the interval. A positive step must
## land on minimum + n * step. or_greater and or_less match the export
## hint. Null matches, so NotNull stays a separate constraint.
var minimum: float = 0.0
var maximum: float = 1.0
var step: float = 0.0
var or_greater: bool = false
var or_less: bool = false
const repeatable := true


func is_valid(candidate: Variant) -> bool:
	if candidate == null:
		return true
	if not _bounds_ok():
		return false
	if not (candidate is int or candidate is float):
		return false
	var number := float(candidate)
	if number < minimum and not or_less:
		return false
	if number > maximum and not or_greater:
		return false
	if step <= 0.0:
		return true
	var steps := (number - minimum) / step
	return is_equal_approx(steps, round(steps))


func violation_message(candidate: Variant) -> String:
	if not _bounds_ok():
		return "needs minimum at or below maximum and a step of at least 0"
	if candidate != null and not (candidate is int or candidate is float):
		return "must be a number"
	if step > 0.0:
		return "must fall on steps of %s from %s to %s" % [step, minimum, maximum]
	return "must be from %s to %s" % [minimum, maximum]


func _bounds_ok() -> bool:
	if minimum <= maximum and step >= 0.0:
		return true
	push_error("Validation: @ValueRange needs minimum at or below maximum and a step of at least 0.")
	return false
