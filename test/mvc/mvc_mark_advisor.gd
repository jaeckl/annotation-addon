class_name MvcMarkAdvisor
extends PropertyAdvisor

## Rewrites 99 gold to 5, and rejects a negative. Every other value passes
## through, so the rest of the suite keeps its own assignments.


func advise(_owner: Object, property: StringName, value: Variant) -> Dictionary:
	if String(property) != "gold" or not (value is int):
		return {"ok": true, "value": value}
	if int(value) == 99:
		return {"ok": true, "value": 5}
	if int(value) < 0:
		return {"ok": false, "message": "gold stays up", "value": value}
	return {"ok": true, "value": value}
