@Component
class_name SchedulePulse
extends RefCounted

var hits := 0


@Scheduled("1f")
func tick() -> void:
	hits += 1
