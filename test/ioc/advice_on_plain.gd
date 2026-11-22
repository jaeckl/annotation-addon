@Component
class_name AdviceOnPlain
extends RefCounted


@Before(Logged)
func ping(_join: JoinPoint) -> void:
	pass
