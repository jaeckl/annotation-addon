@Component
class_name LifeDerived
extends LifeBase


@Ready
func from_derived() -> void:
	log.append("ready:derived")


@OnDestroy
func down_derived() -> void:
	log.append("down:derived")
