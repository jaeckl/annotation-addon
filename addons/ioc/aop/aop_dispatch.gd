class_name AopDispatch
extends RefCounted

## Runs one advised call. Befores run first, then arounds, then the original
## method, then afters. Within each kind the container recorded the advice in
## source order. This stays on the main thread.
static var _inflight: Dictionary = {}


static func push(script: GDScript, chains: Dictionary) -> void:
	var stack: Array = _inflight.get(script, [])
	stack.append(chains)
	_inflight[script] = stack


static func pop(script: GDScript) -> void:
	var stack: Array = _inflight.get(script, [])
	if not stack.is_empty():
		stack.pop_back()
	if stack.is_empty():
		_inflight.erase(script)
		return
	_inflight[script] = stack


static func invoke(target: Object, method: StringName, args: Array, proceed: Callable, chains: Dictionary) -> Variant:
	var active := chains
	if active.is_empty():
		active = _inflight_for(target.get_script())
	var steps: Array = active.get(method, [])
	var befores: Array = []
	var arounds: Array = []
	var afters: Array = []
	for step in steps:
		match String(step.get("kind", "")):
			"before":
				befores.append(step)
			"around":
				arounds.append(step)
			"after":
				afters.append(step)
	var join := JoinPoint.new()
	join.target = target
	join.method = method
	join.args = args
	for step in befores:
		_call_advice(step, join)
	var result: Variant = continue_around(target, method, join.args, proceed, arounds, 0)
	join.result = result
	for step in afters:
		_call_advice(step, join)
	return result


static func continue_around(target: Object, method: StringName, args: Array, proceed: Callable, arounds: Array, index: int) -> Variant:
	if index >= arounds.size():
		return proceed.call(args)
	var step: Dictionary = arounds[index]
	var join := ProceedingJoinPoint.new()
	join.target = target
	join.method = method
	join.args = args
	join._proceed = proceed
	join._arounds = arounds
	join._index = index
	var aspect: Object = step.get("aspect")
	if aspect == null:
		return null
	return _call_advice(step, join)


static func _call_advice(step: Dictionary, join: JoinPoint) -> Variant:
	var aspect: Object = step.get("aspect")
	if aspect == null:
		return null
	var value: Variant = aspect.call(step.get("method"), join)
	if value is Object and (value as Object).get_class() == "GDScriptFunctionState":
		push_error("IOC: advice cannot await.")
	return value


static func _inflight_for(script: Variant) -> Dictionary:
	var stack: Array = _inflight.get(script, [])
	if stack.is_empty():
		return {}
	var chains: Variant = stack.back()
	if chains is Dictionary:
		return chains
	return {}
