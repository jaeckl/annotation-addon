@Primary
@Component
class_name MemoryLogger
extends GameLogger

## Test GameLogger. Wins over PrintLogger via @Primary.

var lines: Array = []


func log(level: StringName, message: String) -> void:
	lines.append("%s:%s" % [String(level), message])
