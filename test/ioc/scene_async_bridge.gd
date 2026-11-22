@ConditionalOnMissingNode(type_name="AbsentMarker")
@Component
class_name SceneAsyncBridge
extends RefCounted

@Inject var gate: AsyncLatch
var started: int = 0
var noted: int = 0


@EventListener
@Async
func on_pace(event: PaceChanged) -> PaceNoted:
	started += 1
	await gate.opened
	return PaceNoted.new(event.current)


@EventListener
func on_noted(_event: PaceNoted) -> void:
	noted += 1
