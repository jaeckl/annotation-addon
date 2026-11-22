class_name StageCard
extends RefCounted

## Example of the Godot constraints. Defaults are values this project has:
## the demo scene, the samples folder, the Master bus, ui_accept, and en.
@ValueRange(minimum=0.0, maximum=1.0, step=0.1)
var volume: float = 0.5
@ValueRange(minimum=0.0, maximum=1.0, or_greater=true)
var loud: float = 2.0
@OneOf(values=["town", "radio"])
var title: String = "town"
@File(extension="tscn")
var scene: String = "res://samples/ioc/demo.tscn"
@Dir
var folder: String = "res://samples/ioc"
@Layers(count=4)
var mask: int = 3
@AudioBus
var bus: String = "Master"
@InputAction
var action: String = "ui_accept"
@Locale
var locale: String = "en"
