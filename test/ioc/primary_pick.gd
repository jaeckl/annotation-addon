@ConditionalOnProperty(key="ioc/primary_fixtures", having_value="yes")
@Primary
@Component
class_name PrimaryPick
extends PrimaryKind

func tag() -> String:
	return "pick"
