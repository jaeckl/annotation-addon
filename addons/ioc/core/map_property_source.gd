class_name MapPropertySource
extends PropertySource

## Keys already flattened to section/key. The parser fills this. A caller
## does not mutate the dictionary after the source is added.
var _values: Dictionary = {}


func fill(values: Dictionary) -> void:
	_values = values


func contains(key: String) -> bool:
	return _values.has(key)


func get_value(key: String) -> Variant:
	return _values.get(key, null)
