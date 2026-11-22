class_name Clamp
extends Preparation

## Holds a number inside minimum and maximum. An int stays an int. Any other
## value is unchanged.
var minimum: float = 0.0
var maximum: float = 1.0


func apply(candidate: Variant) -> Variant:
	if minimum > maximum:
		fail("Prepare: @Clamp needs a minimum at or below the maximum.")
		return candidate
	if candidate is int:
		return clampi(int(candidate), int(minimum), int(maximum))
	if candidate is float:
		return clampf(float(candidate), minimum, maximum)
	return candidate
