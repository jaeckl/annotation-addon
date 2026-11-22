@Component
class_name LifeBase
extends RefCounted

var log: Array = []


@Ready
func from_base() -> void:
	log.append("ready:base")


@OnDestroy
func down_base() -> void:
	log.append("down:base")
