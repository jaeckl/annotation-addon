class_name SaveMarkAdvisor
extends FieldAdvisor

## Rewrites score 99 to 5, rejects a negative score, and returns a broken
## result for force_break so the mapper can refuse a bad advisor.


func advise(_owner: Object, property: StringName, value: Variant) -> Variant:
	var name := String(property)
	if name == "force_break":
		return null
	if name != "score" or not (value is int):
		return {"ok": true, "value": value}
	if int(value) == 99:
		return {"ok": true, "value": 5}
	if int(value) < 0:
		return {"ok": false, "message": "score stays up", "value": value}
	return {"ok": true, "value": value}
