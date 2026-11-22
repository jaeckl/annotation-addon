class_name Layers
extends Constraint

## Matches an int whose set bits lie in the first count layers. Godot uses
## 32. 0 matches. A negative value does not. Null matches, so NotNull stays
## a separate constraint.
var count: int = 32
const repeatable := true


func is_valid(candidate: Variant) -> bool:
	if candidate == null:
		return true
	if not _count_ok():
		return false
	if not (candidate is int):
		return false
	var bits := int(candidate)
	if bits < 0:
		return false
	var allowed := (1 << count) - 1
	return (bits & ~allowed) == 0


func violation_message(candidate: Variant) -> String:
	if not _count_ok():
		return "needs a layer count from 1 to 32"
	if candidate != null and not (candidate is int):
		return "must be an int"
	return "must use only the first %s layers" % count


func _count_ok() -> bool:
	if count >= 1 and count <= 32:
		return true
	push_error("Validation: @Layers count must be from 1 to 32.")
	return false
