@Component
class_name BadEventReturn
extends RefCounted

@EventListener
func on_health(_event: HealthChanged) -> int:
	return 1
