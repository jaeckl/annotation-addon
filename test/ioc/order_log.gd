@Aspect
@Component
class_name OrderLog
extends RefCounted

var log: Array = []


@Before(Timed)
func first(_join: JoinPoint) -> void:
	log.append("first")


@Before(Timed)
func second(_join: JoinPoint) -> void:
	log.append("second")
