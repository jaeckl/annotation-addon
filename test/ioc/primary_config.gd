@Configuration
class_name PrimaryConfig
extends RefCounted


@ConditionalOnProperty(key="ioc/primary_factory", having_value="yes")
@Primary
@Component
func made() -> PrimaryMade:
	return PrimaryMade.new()
