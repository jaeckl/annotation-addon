@Component
class_name ScheduleWoven
extends RefCounted

var ran := 0


@Logged
@Scheduled("1f")
func tick() -> void:
	ran += 1
