class_name Heading
extends RefCounted

## Vector preparations. A zero vector stays zero.
@Normalize
var direction: Vector2 = Vector2(3, 4)
@Normalize
var idle: Vector2 = Vector2.ZERO
@LimitLength(maximum=2.0)
var velocity: Vector3 = Vector3(3, 0, 0)
