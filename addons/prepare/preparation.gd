class_name Preparation
extends GDScriptAnnotation

## Rewrites one field or constructor parameter. A subclass overrides apply.
## A value of the wrong kind comes back unchanged. Several preparations on
## the same target run in source order, and each one sees the previous result.


func apply(candidate: Variant) -> Variant:
	return candidate


func fail(message: String) -> void:
	push_error(message)
	set_meta(&"prepare_failed", true)
	set_meta(&"prepare_message", message)


func failed() -> bool:
	return has_meta(&"prepare_failed")


func reset() -> void:
	if has_meta(&"prepare_failed"):
		remove_meta(&"prepare_failed")
	if has_meta(&"prepare_message"):
		remove_meta(&"prepare_message")


func failure_message() -> String:
	if has_meta(&"prepare_message"):
		return String(get_meta(&"prepare_message"))
	return ""
