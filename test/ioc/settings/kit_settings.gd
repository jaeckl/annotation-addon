@ConfigurationProperties(prefix="kit")
class_name KitSettings
extends Resource

@export var room: PackedScene
@export var note: KitNote
@export var any: Resource
@export var clip: AudioStream
@export var pace: int = 0
@export var title: String = "kit"
