@ConditionalOnProperty(key="audio/missing")
@ConditionalOnMissingComponent(type_name="SpareClock")
@Component
class_name GatedSpare
extends RefCounted
