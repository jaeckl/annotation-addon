@Component
class_name ScheduleDerived
extends ScheduleBase


@Scheduled("1f")
func from_derived() -> void:
	log.append("derived")
