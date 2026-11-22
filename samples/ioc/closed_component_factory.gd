@ConditionalOnComponent(type_name="SpareClock")
@Configuration
class_name ClosedComponentFactory
extends RefCounted


@Component
func ghost() -> ComponentGhost:
	return ComponentGhost.new()
