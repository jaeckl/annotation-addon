class_name PropertyConverter
extends RefCounted

## Turns a raw property value into the exported field type. The binder walks
## binder.converters and uses the first handles that returns true. A custom
## converter is another subclass. The container installs every concrete
## global subclass in front of the scalar converter. This is not an @Inject
## dependency.


func handles(_target_type: int, _value: Variant) -> bool:
	return false


func convert(_target_type: int, value: Variant) -> Variant:
	return value
