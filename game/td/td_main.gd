extends Control

## Local entry for the TD demo. Open this scene (or set it as main) with
## IOCMainLoop, then New Game / Continue. @Inject fills on enter-tree.

@Inject var runs: Runs
@Inject var slots: SaveSlots

@onready var status: Label = $Panel/Status


func _ready() -> void:
	$Panel/NewGame.pressed.connect(_new_game)
	$Panel/Continue.pressed.connect(_continue)
	_refresh()


func _refresh() -> void:
	if slots == null:
		status.text = "IOCMainLoop missing — set application/run/main_loop_type to IOCMainLoop"
		$Panel/Continue.disabled = true
		return
	var has := slots.has("td1")
	$Panel/Continue.disabled = not has
	status.text = "Save slot td1 ready" if has else "No save yet — start a new game"


func _new_game() -> void:
	if runs == null:
		return
	if runs.is_open():
		runs.end()
	if not runs.start():
		status.text = "Could not start run"
		return
	if slots != null:
		slots.pending_slot = ""
	get_tree().paused = false
	get_tree().change_scene_to_file("res://game/td/battle/battle.tscn")


func _continue() -> void:
	if slots == null or not slots.has("td1"):
		status.text = "No save in slot td1"
		return
	# SaveContinueHook loads pending_slot when battle opens (before
	# @SceneScoped), with body_parent = the battle root.
	slots.pending_slot = "td1"
	if runs != null and runs.is_open():
		runs.end()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://game/td/battle/battle.tscn")
