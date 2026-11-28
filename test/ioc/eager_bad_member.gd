@Component
class_name EagerBadMember
extends RefCounted

@Eager var label := ""


@Lazy
func ping() -> void:
	pass
