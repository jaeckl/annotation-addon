@Component
@Model
class_name MvcStash
extends RefCounted

@Property
var gold: int = 0

@Property
var title: String = "shop"

@Property
var bonus: int = 1


@Logged
func add_coin() -> void:
	gold += 1


func rename(next: String) -> void:
	title = next
