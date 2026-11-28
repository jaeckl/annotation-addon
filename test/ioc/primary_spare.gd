@ConditionalOnProperty(key="ioc/primary_factory", having_value="yes")
@Component
class_name PrimarySpare
extends PrimaryKind

func tag() -> String:
	return "spare"
