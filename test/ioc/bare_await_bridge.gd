@Component
class_name BareAwaitBridge
extends RefCounted

@Inject var gate: AsyncLatch
var started: int = 0
var finished: int = 0


@EventListener
func on_pace(event: PaceChanged) -> PaceNoted:
	started += 1
	await gate.opened
	finished += 1
	return PaceNoted.new(event.current)
