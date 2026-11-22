@ConditionalOnProperty(key="audio/missing")
@ConfigurationProperties(prefix="audio")
class_name HiddenAudio
extends Resource

@export var master: float = 1.0
