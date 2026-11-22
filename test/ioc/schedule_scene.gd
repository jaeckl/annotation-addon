@ConditionalOnMissingNode(type_name="AbsentMarker")
@Component
class_name ScheduleScene
extends RefCounted

var hits := 0


@Scheduled("1f")
func tick() -> void:
	hits += 1
