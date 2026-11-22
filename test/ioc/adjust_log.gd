@Aspect
@Component
class_name AdjustLog
extends RefCounted


@Around(Adjusted)
func around_call(join: ProceedingJoinPoint) -> Variant:
	return join.proceed([int(join.args[0]) + 1])
