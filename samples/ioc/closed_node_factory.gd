@ConditionalOnNode(type_name="AbsentMarker")
@Configuration
class_name ClosedNodeFactory
extends RefCounted


@Component
func ghost() -> NodeGhost:
	return NodeGhost.new()
