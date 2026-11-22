@ConditionalOnComponent(type_name="SpareClock")
@ConfigurationProperties(prefix="audio")
class_name HiddenComponentAudio
extends Resource

@export var master: float = 1.0
