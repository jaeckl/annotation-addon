@Component
class_name AsyncSilent
extends RefCounted

@Inject var gate: AsyncLatch
var finished: int = 0


@EventListener
@Async
func on_pace(_event: PaceChanged) -> void:
	await gate.opened
	finished += 1
