@RunScope
@Component
class_name RunTicker
extends RefCounted

@Inject var log: RunLog
var heard := 0
var ending := 0
var beats := 0
var keys := 0
var polls := 0
var visits: Array = []


@UnhandledInput
func on_key(_event: InputEventKey) -> void:
	keys += 1


@InputAction("ui_accept")
func held(_down: bool) -> void:
	polls += 1


@Process
func on_idle(_delta: float) -> void:
	log.lines.append("tick:run")


@Scheduled("2f")
func beat() -> void:
	beats += 1


@EventListener
func on_ping(_ping: RunPing) -> void:
	heard += 1


@EventListener
func on_ending(_event: RunEnding) -> void:
	ending += 1


@OnSceneEnter
func entered(root: Node) -> void:
	visits.append("in:%s" % root.name)


@OnSceneExit
func left(root: Node) -> void:
	visits.append("out:%s" % root.name)
