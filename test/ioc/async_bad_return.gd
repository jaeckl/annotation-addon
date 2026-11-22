@Component
class_name AsyncBadReturn
extends RefCounted

@Inject var gate: AsyncLatch


@EventListener
@Async
func on_pace(_event: PaceChanged) -> int:
	await gate.opened
	return 1
