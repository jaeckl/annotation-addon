@ConditionalOnComponent(type_name="Jukebox")
@ConfigurationProperties(prefix="audio")
class_name JukeboxAudio
extends Resource

@export var master: float = 1.0
