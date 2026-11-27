@Persist
@RunScope
@Component
class_name KeptParty
extends RefCounted

@Serialize var mob: KeptMob
var ready_hp := -1


@Ready
func boot() -> void:
	ready_hp = mob.hp if mob != null else -1
