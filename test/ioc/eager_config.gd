@Configuration
class_name EagerConfig
extends RefCounted


@ConditionalOnProperty(key="ioc/eager_fixtures", having_value="yes")
@Eager
@RunScope
@Component
func purse(log: RunLog) -> EagerPurse:
	var made := EagerPurse.new()
	made.log = log
	return made
