class_name Condition
extends GDScriptAnnotation

## A yes-or-no gate read before a definition is registered. Several conditions
## on the same class or method all have to match. A subclass overrides matches.
## The container does not special-case the subclass name.


func matches(_environment: PropertyEnvironment) -> bool:
	return false
