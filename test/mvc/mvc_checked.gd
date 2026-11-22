@Component
@Model
class_name MvcChecked
extends RefCounted

@Property
@Trim
@NotEmpty
var title: String = "shop"

@Property
@Max(9)
var gold: int = 0

@Property
@Clamp(2, 1)
var pace: int = 0


@Ready
func spoil() -> void:
	title = "  hall  "
	gold = 40
