class_name LimitLength
extends Preparation

## Limits Vector2, Vector3, and Vector4 to maximum. A shorter vector stays
## as it is. Vector4 has no limit_length, so it is scaled from its length.
## Any other value is unchanged. The first attribute is maximum, so
## @LimitLength(2.0) is positional.
var maximum: float = 1.0


func apply(candidate: Variant) -> Variant:
	if maximum < 0.0:
		fail("Prepare: @LimitLength needs a maximum of at least 0.")
		return candidate
	if candidate is Vector2:
		return (candidate as Vector2).limit_length(maximum)
	if candidate is Vector3:
		return (candidate as Vector3).limit_length(maximum)
	if candidate is Vector4:
		return _limit4(candidate as Vector4)
	return candidate


func _limit4(vector: Vector4) -> Vector4:
	var length := vector.length()
	if length <= maximum or is_zero_approx(length):
		return vector
	return vector / length * maximum
