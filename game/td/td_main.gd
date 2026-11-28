extends Control

## Local entry for the TD demo. Open this scene (or set it as main) with
## IOCMainLoop, then New Game / Continue.

@onready var status: Label = $Panel/Status


func _ready() -> void:
	$Panel/NewGame.pressed.connect(_new_game)
	$Panel/Continue.pressed.connect(_continue)
	_refresh()


func _refresh() -> void:
	var box := _box()
	if box == null:
		status.text = "IOCMainLoop missing — set application/run/main_loop_type to IOCMainLoop"
		$Panel/Continue.disabled = true
		return
	var slots := box.resolve(SaveSlots) as SaveSlots
	var has := slots != null and slots.has("td1")
	$Panel/Continue.disabled = not has
	status.text = "Save slot td1 ready" if has else "No save yet — start a new game"


func _new_game() -> void:
	var box := _box()
	if box == null:
		return
	var runs := box.resolve(Runs) as Runs
	var slots := box.resolve(SaveSlots) as SaveSlots
	if runs == null:
		return
	if runs.is_open():
		runs.end()
	if not runs.start():
		status.text = "Could not start run"
		return
	if slots != null:
		slots.pending_slot = ""
	# Touch eager run products so Persist write has them.
	box.resolve(TdWallet)
	box.resolve(TdTowerField)
	box.resolve(TdWaveDirector)
	box.resolve(TdMatchFlow)
	box.resolve(TdHudModel)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://game/td/battle/battle.tscn")


func _continue() -> void:
	var box := _box()
	if box == null:
		return
	var slots := box.resolve(SaveSlots) as SaveSlots
	var runs := box.resolve(Runs) as Runs
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


func _box() -> IOCContainer:
	var loop := Engine.get_main_loop() as IOCMainLoop
	if loop == null:
		return null
	return loop.container
