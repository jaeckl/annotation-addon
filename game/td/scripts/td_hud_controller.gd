@Controller
@SceneScoped
@Component
class_name TdHudController
extends RefCounted

## Binds TdHudModel to TdHudView and routes HUD buttons. Battle calls arm()
## after optional save load so run-scoped model/wallet refs stay current.

@Inject var view: TdHudView
@Inject var runs: Runs
@Inject var catalog: TdCatalog
@Inject var screens: ScreenHost

@Bind var gold_label: Label
@Bind var lives_label: Label
@Bind var wave_label: Label
@Bind var status_label: Label
@Bind var upgrade_button: Button
@Bind var arrow_button: Button
@Bind var cannon_button: Button
@Bind var slow_button: Button

var model: TdHudModel
var wallet: TdWallet
var waves: TdWaveDirector
var towers: TdTowerField
var _armed := false


func refresh_run() -> void:
	if runs == null:
		return
	model = runs.resolve(TdHudModel) as TdHudModel
	wallet = runs.resolve(TdWallet) as TdWallet
	waves = runs.resolve(TdWaveDirector) as TdWaveDirector
	towers = runs.resolve(TdTowerField) as TdTowerField


func arm() -> void:
	refresh_run()
	if _armed or model == null:
		return
	_armed = true
	_sync()
	Bindings.link(Bindings.text(gold_label), model.gold_text)
	Bindings.link(Bindings.text(lives_label), model.lives_text)
	Bindings.link(Bindings.text(wave_label), model.wave)
	Bindings.link(Bindings.text(status_label), model.status)
	Bindings.on(arrow_button.pressed).to(_pick_arrow)
	Bindings.on(cannon_button.pressed).to(_pick_cannon)
	Bindings.on(slow_button.pressed).to(_pick_slow)
	Bindings.on(upgrade_button.pressed).to(_upgrade)
	screens.show(view)


@Process
func tick(_delta: float) -> void:
	if not _armed:
		return
	_sync()


func _sync() -> void:
	if wallet != null:
		model.gold_text = "Gold: %d" % wallet.gold
		model.lives_text = "Lives: %d" % wallet.lives
	if waves != null:
		model.wave = "Wave: %d / %d" % [waves.current_display(), waves.wave_count()]
	if towers != null and catalog != null:
		var spec := catalog.tower(towers.build_kind)
		model.status = "Build: %s (%d)  |  click tower twice or U to upgrade" % [
			str(spec.get("label", towers.build_kind)),
			int(spec.get("build_cost", 0)),
		]
		if towers.selected != null:
			var cost := towers.selected.upgrade_cost()
			model.upgrade = "MAX" if cost < 0 else "Upgrade (%d)" % cost
			upgrade_button.disabled = cost < 0
		else:
			model.upgrade = "Upgrade"
			upgrade_button.disabled = true
		upgrade_button.text = model.upgrade


func _pick_arrow() -> void:
	if towers != null:
		towers.select_build(&"arrow")


func _pick_cannon() -> void:
	if towers != null:
		towers.select_build(&"cannon")


func _pick_slow() -> void:
	if towers != null:
		towers.select_build(&"slow")


func _upgrade() -> void:
	if towers != null:
		towers.upgrade_selected()
