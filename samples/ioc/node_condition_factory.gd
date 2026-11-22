@Configuration
class_name NodeConditionFactory
extends RefCounted


@ConditionalOnNode(type_name="Hud")
@Component
func present_gate() -> NodeGate:
	return NodeGate.new()


@ConditionalOnMissingNode(type_name="Hud")
@Component
func missing_gate() -> MissingNodeGate:
	return MissingNodeGate.new()
