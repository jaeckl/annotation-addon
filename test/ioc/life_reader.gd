@Component
class_name LifeReader
extends RefCounted

@Inject var clock: LifeClock
@Inject var log: LifeLog


@Ready
func boot() -> void:
	log.lines.append("ready:reader")


@OnDestroy
func down() -> void:
	log.lines.append("down:reader")
