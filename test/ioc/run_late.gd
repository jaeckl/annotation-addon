@RunScope
@Component
class_name RunLate
extends RefCounted

@Inject var runs: Runs
var found: Object


@OnDestroy
func down() -> void:
	found = runs.resolve(RunPurse)
