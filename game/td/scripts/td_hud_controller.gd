@Controller
@SceneScoped
@Component
class_name TdHudController
extends RefCounted

## Binds TdHudModel to TdHudView and routes HUD buttons. SaveContinueHook
## loads before @SceneScoped build, so @Inject run deps are already fresh.

@Inject var view: TdHudView
@Inject var model: TdHudModel
@Inject var wallet: TdWallet
@Inject var waves: TdWaveDirector
@Inject var towers: TdTowerField
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


@Ready
func arm() -> void:
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
	_sync()


func _sync() -> void:
	if model == null:
		return
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
