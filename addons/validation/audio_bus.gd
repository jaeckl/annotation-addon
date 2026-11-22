class_name AudioBus
extends Constraint

## Matches a bus name AudioServer has. Master is the bus every project
## starts with. Null matches, so NotNull stays a separate constraint.
const repeatable := true


func is_valid(candidate: Variant) -> bool:
	if candidate == null:
		return true
	if not (candidate is String):
		return false
	var bus := String(candidate).strip_edges()
	if bus.is_empty():
		return false
	return AudioServer.get_bus_index(bus) >= 0


func violation_message(_candidate: Variant) -> String:
	return "must be an audio bus"
