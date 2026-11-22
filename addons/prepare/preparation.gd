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


func failed() -> bool:
	return has_meta(&"prepare_failed")
