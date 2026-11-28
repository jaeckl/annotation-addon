@Component
class_name PrintLogger
extends GameLogger

## Default GameLogger. warn → push_warning, error → push_error, else print.


func log(level: StringName, message: String) -> void:
	var text := "[%s] %s" % [String(level), message]
	match String(level):
		"warn":
			push_warning(text)
		"error":
			push_error(text)
		_:
			print(text)
