class_name PropertySource
extends RefCounted

## One named origin of keys. Index 0 in the PropertyEnvironment wins.
## A subclass overrides contains and get_value. A missing key is not null:
## contains is false, and get_value is only called after that.
var source_name: String = ""


func contains(_key: String) -> bool:
	return false


func get_value(_key: String) -> Variant:
	return null
