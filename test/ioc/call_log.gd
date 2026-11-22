@Aspect
@Component
class_name CallLog
extends RefCounted

var calls: Array = []


@Before(Logged)
func before_call(join: JoinPoint) -> void:
	calls.append("before:%s:%s" % [join.method, join.args])


@Around(Logged)
func around_call(join: ProceedingJoinPoint) -> Variant:
	calls.append("around:%s" % join.method)
	return join.proceed()


@After(Logged)
func after_call(join: JoinPoint) -> void:
	calls.append("after:%s:%s" % [join.method, join.result])


@Logged
func own() -> String:
	return "aspect"
