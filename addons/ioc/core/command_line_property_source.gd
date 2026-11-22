class_name CommandLinePropertySource
extends PropertySource

## User arguments after --. --audio/master=0.2 stores the string 0.2.
## An argument without an equals sign is ignored.
var _values: Dictionary = {}


func _init() -> void:
	source_name = "command-line"
	for argument in OS.get_cmdline_user_args():
		var text := String(argument)
		if not text.begins_with("--"):
			continue
		var body := text.substr(2)
		var split_at := body.find("=")
		if split_at <= 0:
			continue
		_values[body.substr(0, split_at)] = body.substr(split_at + 1)


func contains(key: String) -> bool:
	return _values.has(key)


func get_value(key: String) -> Variant:
	return _values.get(key, null)
