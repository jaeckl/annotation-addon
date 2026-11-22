class_name InputAction
extends Constraint

## Matches an action InputMap has. The built-in ui_accept action is one.
## Null matches, so NotNull stays a separate constraint.
const repeatable := true


func is_valid(candidate: Variant) -> bool:
	if candidate == null:
		return true
	if not (candidate is String):
		return false
	var action := String(candidate).strip_edges()
	if action.is_empty():
		return false
	return InputMap.has_action(StringName(action))


func violation_message(_candidate: Variant) -> String:
	return "must be an input action"
