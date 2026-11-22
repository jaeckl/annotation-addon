@Configuration
class_name GateFactory
extends RefCounted


@ConditionalOnProperty(key="combat/enabled", having_value="true")
@Component
func open() -> OpenGate:
	return OpenGate.new()


@ConditionalOnProperty(key="combat/enabled", having_value="false")
@Component
func shut() -> ShutGate:
	return ShutGate.new()
