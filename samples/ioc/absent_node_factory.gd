@ConditionalOnMissingClass(type_name="Node")
@Configuration
class_name AbsentNodeFactory
extends RefCounted


@Component
func ghost() -> AbsentNodeGhost:
	return AbsentNodeGhost.new()
