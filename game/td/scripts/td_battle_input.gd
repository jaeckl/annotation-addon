@SceneScoped
@Component
class_name TdBattleInput
extends RefCounted

## Play-time clicks and hotkeys. Esc pause stays on the battle node so it
## still works while the tree is paused (@UnhandledInput is skipped then).

@Inject var flow: TdMatchFlow
@Inject var towers: TdTowerField

var world: Node2D


func bind_world(root: Node2D) -> void:
	world = root


@UnhandledInput
@OncePer("frame")
func on_play_input(event: InputEvent) -> bool:
	if flow == null or flow.state != TdMatchFlow.Phase.PLAYING:
		return false
	if world == null or towers == null:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				towers.select_build(&"arrow")
				return true
			KEY_2:
				towers.select_build(&"cannon")
				return true
			KEY_3:
				towers.select_build(&"slow")
				return true
			KEY_U:
				towers.upgrade_selected()
				return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local := world.to_local(world.get_global_mouse_position())
		var before := towers.towers.size()
		if towers.try_build_at(local):
			return true
		if towers.towers.size() == before:
			towers.try_select_or_upgrade(local)
		return true
	return false
