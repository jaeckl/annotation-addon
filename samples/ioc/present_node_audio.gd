@ConditionalOnNode(type_name="Hud")
@ConfigurationProperties(prefix="audio")
class_name PresentNodeAudio
extends Resource

@export var master: float = 1.0
