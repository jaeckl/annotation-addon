@ConditionalOnProperty(key="ioc/eager_fixtures", having_value="yes")
@RunScope
@Component
class_name EagerPlain
extends RefCounted

@Inject var log: RunLog


@Process
func on_idle(_delta: float) -> void:
	log.lines.append("tick:plain")
