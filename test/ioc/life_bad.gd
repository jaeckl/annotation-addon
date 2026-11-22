@Ready
@Component
class_name LifeBad
extends RefCounted

@Ready var label := ""


@OnDestroy
static func parked() -> void:
	pass


@Ready
func takes(_n: int) -> void:
	pass


func marked(@Ready _n: int) -> void:
	pass
