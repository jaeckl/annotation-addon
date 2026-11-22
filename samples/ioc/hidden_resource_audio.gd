@ConditionalOnResource(path="res://addons/no_such_addon/plugin.cfg")
@ConfigurationProperties(prefix="audio")
class_name HiddenResourceAudio
extends Resource

@export var master: float = 1.0
