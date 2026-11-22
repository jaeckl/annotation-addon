@Configuration
class_name EventConfig
extends RefCounted

## A configuration is not a listener. The method stays uncalled.
@EventListener
func on_health(_event: HealthChanged) -> void:
	pass
