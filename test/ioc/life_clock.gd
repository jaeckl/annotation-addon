@Component
class_name LifeClock
extends RefCounted

@Inject var log: LifeLog


@Ready
func boot() -> void:
	log.lines.append("ready:clock")


@OnDestroy
func down() -> void:
	log.lines.append("down:clock")
