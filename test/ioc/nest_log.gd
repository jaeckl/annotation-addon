@Aspect
@Component
class_name NestLog
extends RefCounted

var log: Array = []


@Around(NestedMark)
func outer(join: ProceedingJoinPoint) -> Variant:
	log.append("outer")
	var result: Variant = join.proceed()
	log.append("outer-done")
	return result


@Around(NestedMark)
func inner(join: ProceedingJoinPoint) -> Variant:
	log.append("inner")
	var result: Variant = join.proceed()
	log.append("inner-done")
	return result
