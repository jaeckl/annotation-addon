@Configuration
class_name ClassFactory
extends RefCounted


@ConditionalOnClass(type_name="Node")
@Component
func native_gate() -> NativeGate:
	return NativeGate.new()


@ConditionalOnClass(type_name="NoSuchAddon")
@Component
func addon_gate() -> AddonGate:
	return AddonGate.new()


@ConditionalOnMissingClass(type_name="NoSuchAddon")
@Component
func fallback_gate() -> FallbackGate:
	return FallbackGate.new()
