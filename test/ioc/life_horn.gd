@Component
class_name LifeHorn
extends RefCounted

var heard := 0
@Inject var events: EventPublisher


@EventListener
func on_ping(_ping: LifePing) -> void:
	heard += 1


@Ready
func boot() -> void:
	events.publish(LifePing.new())
