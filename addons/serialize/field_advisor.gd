class_name FieldAdvisor
extends RefCounted

## One step on a planned @Serialize field while the mapper writes a document
## or reads it back. A lower order runs first. advise returns
## {ok: true, value: next} to continue. {ok: false, message} fails the write
## or read. The codec still only sees the document bytes.
var order: int = 0


func advise(_owner: Object, _property: StringName, value: Variant) -> Variant:
	return {"ok": true, "value": value}
