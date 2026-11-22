@Aspect
@Component
class_name SkipLog
extends RefCounted

var ran_after := false
var result: Variant


@Around(Skipped)
func around_call(_join: ProceedingJoinPoint) -> Variant:
	return "skipped"


@After(Skipped)
func after_call(join: JoinPoint) -> void:
	ran_after = true
	result = join.result
