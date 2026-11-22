@Component
class_name AsyncLoopHealth
extends RefCounted

@Inject var gate: AsyncLatch


@EventListener
@Async
func on_health(_event: HealthChanged) -> HealthChanged:
	await gate.opened
	return HealthChanged.new(0)
