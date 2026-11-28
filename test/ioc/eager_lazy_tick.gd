@ConditionalOnProperty(key="ioc/eager_fixtures", having_value="yes")
@Lazy
@RunScope
@Component
class_name EagerLazyTick
extends RefCounted

@Inject var log: RunLog


@Process
func on_idle(_delta: float) -> void:
	log.lines.append("tick:lazy")
