@Configuration
class_name ResourceFactory
extends RefCounted


@ConditionalOnResource(path="res://config/10-defaults.cfg")
@Component
func present_gate() -> ResourceGate:
	return ResourceGate.new()


@ConditionalOnResource(path="res://addons/no_such_addon/plugin.cfg")
@Component
func missing_gate() -> MissingResourceGate:
	return MissingResourceGate.new()
