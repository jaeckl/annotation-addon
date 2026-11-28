@ConditionalOnProperty(key="ioc/primary_clash", having_value="yes")
@Primary
@Component
class_name PrimaryRival
extends PrimaryKind

func tag() -> String:
	return "rival"
