@ConditionalOnProperty(key="ioc/eager_fixtures", having_value="yes")
@Eager
@RunScope
@Component
class_name EagerTick
extends RefCounted

@Inject var log: RunLog
var started := 0


@Process
func on_idle(_delta: float) -> void:
	log.lines.append("tick:eager")


@EventListener
func on_started(_event: RunStarted) -> void:
	started += 1
