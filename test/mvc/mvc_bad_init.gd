@Component
@Model
class_name MvcBadInit
extends RefCounted

@Property
var gold: int = 0


func _init() -> void:
	gold = 4
