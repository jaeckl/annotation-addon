@ConditionalOnMissingNode(type_name="AbsentMarker")
@Component
class_name RunSceneTick
extends RefCounted

@Inject var log: RunLog
@Inject var wallet: RunWallet
var started := 0


@Process
func on_idle(_delta: float) -> void:
	log.lines.append("tick:scene")


@EventListener
func on_started(_event: RunStarted) -> void:
	started += 1
