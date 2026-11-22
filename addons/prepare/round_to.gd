class_name RoundTo
extends Preparation

## Snaps a number to step. A whole result of an int stays an int. Any other
## value is unchanged. The first attribute is step, so @RoundTo(0.5) is positional.
var step: float = 1.0


func apply(candidate: Variant) -> Variant:
	if step <= 0.0:
		fail("Prepare: @RoundTo needs a step greater than 0.")
		return candidate
	if not (candidate is int or candidate is float):
		return candidate
	var snapped_value := snapped(float(candidate), step)
	if candidate is int and is_equal_approx(snapped_value, round(snapped_value)):
		return int(round(snapped_value))
	return snapped_value
