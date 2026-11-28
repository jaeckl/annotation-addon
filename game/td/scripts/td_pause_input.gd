@ProcessMode(Node.PROCESS_MODE_ALWAYS)
@SceneScoped
@Component
class_name TdPauseInput
extends Node

## Esc pause/resume while the tree is paused. Play clicks stay on
## TdBattleInput so they do not fire under pause.

@Inject var flow: TdMatchFlow


func _unhandled_input(event: InputEvent) -> void:
	if flow == null:
		return
	if event.is_action_pressed("ui_cancel"):
		if flow.state == TdMatchFlow.Phase.PLAYING or flow.state == TdMatchFlow.Phase.PAUSED:
			flow.toggle_pause()
		get_viewport().set_input_as_handled()
