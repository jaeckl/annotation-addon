@Component
class_name ScheduleOrder
extends RefCounted

var log: Array = []


@Scheduled("1f")
func first() -> void:
	log.append("first")


@Scheduled("1f")
func second() -> void:
	log.append("second")
