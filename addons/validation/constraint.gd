class_name Constraint
extends GDScriptAnnotation

## A check on one field or constructor parameter. A subclass overrides
## is_valid. Several constraints on the same target all run. The validator
## does not special-case the subclass name.


func is_valid(_candidate: Variant) -> bool:
	return true


func violation_message(_candidate: Variant) -> String:
	return "is invalid"
