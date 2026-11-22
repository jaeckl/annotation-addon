@Component
class_name BadEventListener
extends RefCounted

## Two parameters are not a listener. Discovery reports it and never calls it.
@EventListener
func on_health(_event: HealthChanged, _extra: int) -> void:
	pass
