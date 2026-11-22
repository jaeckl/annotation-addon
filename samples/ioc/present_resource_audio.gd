@ConditionalOnResource(path="res://config/10-defaults.cfg")
@ConfigurationProperties(prefix="audio")
class_name PresentResourceAudio
extends Resource

@export var master: float = 1.0
