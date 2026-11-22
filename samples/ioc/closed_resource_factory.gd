@ConditionalOnResource(path="res://addons/no_such_addon/plugin.cfg")
@Configuration
class_name ClosedResourceFactory
extends RefCounted


@Component
func ghost() -> ResourceGhost:
	return ResourceGhost.new()
