@Component
class_name LoopingHealth
extends RefCounted

## Returns the same event type. The container refuses the second publish.
@EventListener
func on_health(_event: HealthChanged) -> HealthChanged:
	return HealthChanged.new(0)
