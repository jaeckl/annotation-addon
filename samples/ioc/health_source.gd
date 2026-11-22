@Component
class_name HealthSource
extends RefCounted

@Inject var events: EventPublisher


func raise(amount: int) -> void:
	events.publish(HealthChanged.new(amount))


func raise_critical(amount: int) -> void:
	events.publish(CriticalHealth.new(amount))


func raise_mana(amount: int) -> void:
	events.publish(ManaChanged.new(amount))
