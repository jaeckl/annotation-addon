@Component
@Model
class_name MvcBadSetter
extends RefCounted

@Property
var gold: int = 0:
	set(next):
		gold = next
