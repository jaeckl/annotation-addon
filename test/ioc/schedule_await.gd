@Component
class_name ScheduleAwait
extends RefCounted

signal resume
var started := 0


@Scheduled("1f")
func tick() -> void:
	started += 1
	await resume
