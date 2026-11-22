@Configuration
class_name ComponentFactory
extends RefCounted


@ConditionalOnComponent(type_name="Jukebox")
@Component
func jukebox_gate() -> JukeboxGate:
	return JukeboxGate.new()


@ConditionalOnComponent(type_name="SpareClock")
@Component
func spare_gate() -> SpareGate:
	return SpareGate.new()


@ConditionalOnMissingComponent(type_name="SpareClock")
@Component
func spare_fallback() -> SpareFallback:
	return SpareFallback.new()
