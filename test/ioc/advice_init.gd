@Component
class_name AdviceInit
extends RefCounted


@Logged
func _init() -> void:
	pass


@Logged
static func stat() -> String:
	return "stat"
