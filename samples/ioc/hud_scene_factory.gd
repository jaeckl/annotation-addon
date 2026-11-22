@ConditionalOnNode(type_name="Hud")
@Configuration
class_name HudSceneFactory
extends RefCounted


@Component
func mark() -> NodeFactoryMark:
	return NodeFactoryMark.new()
