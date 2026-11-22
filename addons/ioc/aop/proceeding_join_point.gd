class_name ProceedingJoinPoint
extends JoinPoint

## The join point handed to @Around. proceed runs the next around, or the
## original method when this is the last one. An argument array replaces
## args for that call. Omitting it keeps the current args.
var _proceed: Callable
var _arounds: Array = []
var _index := 0


func proceed(replacement: Variant = null) -> Variant:
	var call_args := args
	if replacement != null:
		if not (replacement is Array):
			push_error("IOC: proceed needs an argument array.")
			return null
		call_args = replacement
	return AopDispatch.continue_around(target, method, call_args, _proceed, _arounds, _index + 1)
