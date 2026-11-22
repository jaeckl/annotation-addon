class_name PropertyConverter
extends RefCounted

## Turns a raw property value into the exported field type. The binder walks
## binder.converters and uses the first handles that returns true. A custom
## converter is another subclass. The container installs every concrete
## global subclass in front of the resource and scalar converters. This is
## not an @Inject dependency. target_class is the field class for an object
## field, and empty for a scalar. failure is a sentence the binder appends
## to the field name when convert cannot produce a value.
var failure: String = ""


func handles(_target_type: int, _value: Variant, _target_class: String = "") -> bool:
	return false


func convert(_target_type: int, value: Variant, _target_class: String = "") -> Variant:
	return value
