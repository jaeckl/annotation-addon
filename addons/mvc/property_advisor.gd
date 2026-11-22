class_name PropertyAdvisor
extends RefCounted

## One step before a @Property is stored. A lower order runs first.
## Preparation is -100, validation is 100, and a custom step defaults to 0,
## so it sees the prepared value and can still reject it before validation.
## advise returns {ok: true, value: next} to continue. {ok: false, message}
## keeps the previous value. quiet skips the MVC: line when the step already
## reported, which preparation does. violations, when set, are the failures.
var order: int = 0


func advise(_owner: Object, _property: StringName, value: Variant) -> Dictionary:
	return {"ok": true, "value": value}
