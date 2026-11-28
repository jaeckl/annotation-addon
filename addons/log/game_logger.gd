class_name GameLogger
extends RefCounted

## Port for @Logged / @Timed. Games may publish another product that extends
## this class (for example a gdlogging adapter). PrintLogger is the default.


func log(_level: StringName, _message: String) -> void:
	pass
