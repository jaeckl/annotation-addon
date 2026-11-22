@Aspect
@Component
class_name AdviceBadShape
extends RefCounted

@Before(Logged) var label: String = ""


@Before(AdviceNote)
func wrong_pointcut(_join: JoinPoint) -> void:
	pass


@Before(Logged)
func no_args() -> void:
	pass


@Before(Logged)
func two(_join: JoinPoint, _extra: int) -> void:
	pass
