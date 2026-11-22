@Component
class_name HealthDesk
extends RefCounted

## health hears HealthChanged and CriticalHealth. broad hears every Event.
## mana hears ManaChanged only.
var health: Array = []
var broad: Array = []
var mana: Array = []


@EventListener
func on_health(event: HealthChanged) -> void:
	health.append(event)


@EventListener
func on_any(event: Event) -> void:
	broad.append(event)


@EventListener
func on_mana(event: ManaChanged) -> void:
	mana.append(event)
