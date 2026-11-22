@Component
class_name AsyncNotedBridge
extends RefCounted

@Inject var gate: AsyncLatch


@EventListener
@Async
func on_noted(event: PaceNoted) -> PaceDone:
	await gate.next
	return PaceDone.new(event.current)
