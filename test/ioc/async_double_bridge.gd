@Component
class_name AsyncDoubleBridge
extends RefCounted

@Inject var gate: AsyncLatch


@EventListener
@Async
func on_pace(event: PaceChanged) -> PaceNoted:
	await gate.opened
	await gate.next
	return PaceNoted.new(event.current)
