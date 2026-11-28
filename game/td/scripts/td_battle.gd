class_name TdBattle
extends Node2D

## Battle world + pause/end overlays. HUD is TdHudView (MVC).
## Run products bind this root via @OnSceneEnter(TdBattle).
## Esc lives on TdPauseInput (@ProcessMode ALWAYS) so play input stays pausable.

@Inject var settings: TdSettings
@Inject var waves: TdWaveDirector
@Inject var towers: TdTowerField
@Inject var flow: TdMatchFlow
@Inject var slots: SaveSlots
@Inject var runs: Runs
@Inject var battle_input: TdBattleInput
@Inject var hud: TdHudController
@Inject var pause_input: TdPauseInput

@onready var pause_panel: Control = $CanvasLayer/Pause
@onready var end_panel: Control = $CanvasLayer/End


func _ready() -> void:
	# Overlays + redraw while MatchFlow pauses the tree. Esc is TdPauseInput.
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.visible = false
	end_panel.visible = false
	$CanvasLayer/Pause/Resume.pressed.connect(_resume)
	$CanvasLayer/Pause/Save.pressed.connect(_save)
	$CanvasLayer/Pause/Menu.pressed.connect(_to_menu)
	$CanvasLayer/End/Menu.pressed.connect(_to_menu)
	queue_redraw()


func _process(delta: float) -> void:
	var playing: bool = flow == null or flow.state == TdMatchFlow.Phase.PLAYING
	if playing:
		if waves != null:
			waves.advance_creeps(delta)
		if towers != null and waves != null:
			towers.tick(delta, waves.creeps)
	_refresh_panels()
	queue_redraw()


func _resume() -> void:
	if flow != null and flow.state == TdMatchFlow.Phase.PAUSED:
		flow.try_goto(TdMatchFlow.Phase.PLAYING)


func _save() -> void:
	if slots != null:
		slots.write("td1")


func _to_menu() -> void:
	if flow != null and flow.state == TdMatchFlow.Phase.PAUSED:
		flow.try_goto(TdMatchFlow.Phase.PLAYING)
	var tree := get_tree()
	if runs != null and runs.is_open():
		runs.end()
	tree.paused = false
	tree.change_scene_to_file("res://game/td/td_main.tscn")


func _refresh_panels() -> void:
	if flow == null:
		return
	pause_panel.visible = flow.state == TdMatchFlow.Phase.PAUSED
	end_panel.visible = flow.state == TdMatchFlow.Phase.WON or flow.state == TdMatchFlow.Phase.LOST
	if flow.state == TdMatchFlow.Phase.WON:
		$CanvasLayer/End/Title.text = "You win"
	elif flow.state == TdMatchFlow.Phase.LOST:
		$CanvasLayer/End/Title.text = "Defeat"


func _draw() -> void:
	if settings == null:
		return
	var size := settings.cell_size_f()
	for y in settings.grid_height:
		for x in settings.grid_width:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell) * size, Vector2(size, size))
			var color := Color(0.18, 0.2, 0.24) if TdPath.is_path(cell) else Color(0.12, 0.14, 0.16)
			draw_rect(rect, color)
			draw_rect(rect, Color(0.05, 0.05, 0.05), false, 1.0)
