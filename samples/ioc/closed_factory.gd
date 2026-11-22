@ConditionalOnProperty(key="audio/missing")
@Configuration
class_name ClosedFactory
extends RefCounted


@Component
func ghost() -> GhostProduct:
	return GhostProduct.new()
