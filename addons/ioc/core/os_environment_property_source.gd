class_name OsEnvironmentPropertySource
extends PropertySource

## Reads OS environment variables. audio/master also matches AUDIO_MASTER.
## The stored value is the raw string. Typed conversion is a later converter.


func _init() -> void:
	source_name = "os-environment"


func contains(key: String) -> bool:
	return not _variable(key).is_empty()


func get_value(key: String) -> Variant:
	return OS.get_environment(_variable(key))


func _variable(key: String) -> String:
	if OS.has_environment(key):
		return key
	var mapped := key.replace("/", "_").to_upper()
	if OS.has_environment(mapped):
		return mapped
	return ""
