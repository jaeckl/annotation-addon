extends Node2D

## Battle scene root. Not a @Component — filled on enter_tree by the container.

@Inject var settings: TdSettings
@Inject var wallet: TdWallet
@Inject var waves: TdWaveDirector
@Inject var towers: TdTowerField
@Inject var flow: TdMatchFlow
@Inject var catalog: TdCatalog
@Inject var slots: SaveSlots
@Inject var runs: Runs

@onready var hud_gold: Label = $CanvasLayer/HUD/Gold
@onready var hud_lives: Label = $CanvasLayer/HUD/Lives
@onready var hud_wave: Label = $CanvasLayer/HUD/Wave
@onready var hud_status: Label = $CanvasLayer/HUD/Status
@onready var btn_upgrade: Button = $CanvasLayer/HUD/Upgrade
@onready var pause_panel: Control = $CanvasLayer/Pause
@onready var end_panel: Control = $CanvasLayer/End


func _ready() -> void:
	# Keep UI responsive while MatchFlow pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if towers != null:
		towers.bind_world(self)
	if waves != null:
		waves.bind_world(self)
	pause_panel.visible = false
	end_panel.visible = false
	btn_upgrade.pressed.connect(_on_upgrade)
	$CanvasLayer/HUD/Arrow.pressed.connect(func(): _pick(&"arrow"))
	$CanvasLayer/HUD/Cannon.pressed.connect(func(): _pick(&"cannon"))
	$CanvasLayer/HUD/Slow.pressed.connect(func(): _pick(&"slow"))
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
	_refresh_hud()
	_refresh_panels()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if flow == null:
		return
	if event.is_action_pressed("ui_cancel"):
		if flow.state == TdMatchFlow.Phase.PLAYING or flow.state == TdMatchFlow.Phase.PAUSED:
			flow.toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if flow.state != TdMatchFlow.Phase.PLAYING:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_pick(&"arrow")
			KEY_2:
				_pick(&"cannon")
			KEY_3:
				_pick(&"slow")
			KEY_U:
				_on_upgrade()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local := to_local(get_global_mouse_position())
		if towers != null:
			var before := towers.towers.size()
			if towers.try_build_at(local):
				pass
			elif towers.towers.size() == before:
				towers.try_select_or_upgrade(local)
		get_viewport().set_input_as_handled()


func _pick(kind: StringName) -> void:
	if towers != null:
		towers.select_build(kind)


func _on_upgrade() -> void:
	if towers != null:
		towers.upgrade_selected()


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


func _refresh_hud() -> void:
	if wallet != null:
		hud_gold.text = "Gold: %d" % wallet.gold
		hud_lives.text = "Lives: %d" % wallet.lives
	if waves != null:
		hud_wave.text = "Wave: %d / %d" % [waves.current_display(), waves.wave_count()]
	if towers != null and catalog != null:
		var spec := catalog.tower(towers.build_kind)
		hud_status.text = "Build: %s (%d)  |  click tower twice or U to upgrade" % [
			str(spec.get("label", towers.build_kind)),
			int(spec.get("build_cost", 0)),
		]
		if towers.selected != null:
			var cost := towers.selected.upgrade_cost()
			btn_upgrade.text = "MAX" if cost < 0 else "Upgrade (%d)" % cost
			btn_upgrade.disabled = cost < 0
		else:
			btn_upgrade.text = "Upgrade"
			btn_upgrade.disabled = true


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
	var size := float(settings.cell_size) if settings != null else 40.0
	for y in TdPath.HEIGHT:
		for x in TdPath.WIDTH:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell) * size, Vector2(size, size))
			var color := Color(0.18, 0.2, 0.24) if TdPath.is_path(cell) else Color(0.12, 0.14, 0.16)
			draw_rect(rect, color)
			draw_rect(rect, Color(0.05, 0.05, 0.05), false, 1.0)
