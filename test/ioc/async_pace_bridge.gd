@Component
class_name AsyncPaceBridge
extends RefCounted

@Inject var gate: AsyncLatch
var started: int = 0


@EventListener
@Async
func on_pace(event: PaceChanged) -> PaceNoted:
	started += 1
	await gate.opened
	return PaceNoted.new(event.current)
