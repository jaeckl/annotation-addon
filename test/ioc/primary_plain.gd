@ConditionalOnProperty(key="ioc/primary_fixtures", having_value="yes")
@Qualifier("plain")
@Component
class_name PrimaryPlain
extends PrimaryKind

func tag() -> String:
	return "plain"
