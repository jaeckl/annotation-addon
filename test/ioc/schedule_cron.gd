@Component
class_name ScheduleCron
extends RefCounted

var hits := 0


@Scheduled("* * * * * *")
func tick() -> void:
	hits += 1
