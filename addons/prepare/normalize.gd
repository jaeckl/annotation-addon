class_name Normalize
extends Preparation

## Returns the unit vector for Vector2, Vector3, and Vector4. A zero vector
## stays zero. Any other value is unchanged.


func apply(candidate: Variant) -> Variant:
	if candidate is Vector2:
		var vector2 := candidate as Vector2
		if vector2.is_zero_approx():
			return vector2
		return vector2.normalized()
	if candidate is Vector3:
		var vector3 := candidate as Vector3
		if vector3.is_zero_approx():
			return vector3
		return vector3.normalized()
	if candidate is Vector4:
		var vector4 := candidate as Vector4
		if vector4.is_zero_approx():
			return vector4
		return vector4.normalized()
	return candidate
