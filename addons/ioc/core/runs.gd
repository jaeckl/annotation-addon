class_name Runs
extends RefCounted

## App product the container registers. One run is open at a time. start
## opens it, end drops every @RunScope product, and restart does both.
## resolve reads a run product at call time, for code that outlives the run.
var container: IOCContainer


func start() -> bool:
	if container == null:
		push_error("IOC: start has no container.")
		return false
	return container.start_run()


func end() -> bool:
	if container == null:
		push_error("IOC: end has no container.")
		return false
	return container.end_run()


func restart() -> bool:
	if container == null:
		push_error("IOC: restart has no container.")
		return false
	if container.is_run_open() and not container.end_run():
		return false
	return container.start_run()


func is_open() -> bool:
	return container != null and container.is_run_open()


func resolve(type: GDScript, qualifiers: Array = []) -> Object:
	if container == null:
		push_error("IOC: resolve has no container.")
		return null
	return container.resolve_run(type, qualifiers)
