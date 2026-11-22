@Component
class_name PaceBridge
extends RefCounted

@EventListener
func on_pace(event: PaceChanged) -> PaceNoted:
	return PaceNoted.new(event.current)
