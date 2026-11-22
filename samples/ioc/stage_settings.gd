@ConfigurationProperties(prefix="stage")
class_name StageSettings
extends Resource

## No stage/* key is set, so these defaults are what gets validated.
## volume 0.5 is on the 0.1 step. The scene, folder, bus, action, and
## locale exist in this project.
@ValueRange(minimum=0.0, maximum=1.0, step=0.1)
@export var volume: float = 0.5
@OneOf(values=["town", "radio"])
@export var title: String = "town"
@File(extension="tscn")
@export var scene: String = "res://samples/ioc/demo.tscn"
@Dir
@export var folder: String = "res://config"
@Layers(count=4)
@export var mask: int = 3
@AudioBus
@export var bus: String = "Master"
@InputAction
@export var action: String = "ui_accept"
@Locale
@export var locale: String = "en"
