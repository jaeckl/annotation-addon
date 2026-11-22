@Component
class_name ScheduleBase
extends RefCounted

var log: Array = []


@Scheduled("1f")
func from_base() -> void:
	log.append("base")
