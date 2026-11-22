@Component
class_name ImmediateAsyncBridge
extends RefCounted

@EventListener
@Async
func on_pace(event: PaceChanged) -> PaceNoted:
	return PaceNoted.new(event.current)
