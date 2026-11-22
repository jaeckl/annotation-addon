@Aspect
class_name AdviceNoComponent
extends RefCounted


@Before(Logged)
func ping(_join: JoinPoint) -> void:
	pass
