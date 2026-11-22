extends Control

## Runs the first slice and prints one line per check.
## @onready stays a scene path. This node is not a @Component, and the
## container does not fill it.
@onready var report: Label = $Report


func _ready() -> void:
	var lines: PackedStringArray = PackedStringArray()
	var failed := false
	var loop := Engine.get_main_loop() as IOCMainLoop
	if loop == null or loop.container == null:
		lines.append("FAIL main loop is IOCMainLoop")
		_finish(lines, true)
		return
	var box := loop.container
	var party := box.resolve(Party) as Party
	var party_again := box.resolve(Party) as Party
	var music := box.resolve(MusicPlayer) as MusicPlayer
	var hud := box.resolve(Hud) as Hud
	await get_tree().process_frame
	var goblin := box.resolve(Goblin) as Goblin
	var enemy := box.resolve(Enemy)
	var cycle := box.resolve(LoopLeft)
	var factory := box.configuration(CombatFactory) as CombatFactory
	var bad := box.configuration(BadFactory)

	_check(lines, party != null, "party resolved")
	if party == null:
		_finish(lines, true)
		return
	_check(lines, party == party_again, "app scope returns the same party")
	_check(lines, party.clock != null and party.clock.started, "field injects GameClock")
	_check(lines, party.clock == box.resolve(GameClock), "GameClock is one app instance")
	_check(lines, party.weapon != null and party.weapon.clock == party.clock, "factory method receives GameClock")
	_check(lines, party.roster != null and party.roster.clock == party.clock, "_init receives GameClock")
	_check(lines, party.bruiser is Orc and party.bruiser.label() == "orc", "@Qualifier selects Orc")
	_check(lines, party.boss is Dragon and party.boss.label() == "dragon", "@Rank selects Dragon")
	_check(lines, party.stalker is Wolf and party.stalker.label() == "wolf", "@Offline selects Wolf")
	_check(lines, party.escort != null and party.escort.bruiser == party.bruiser, "factory parameter qualifier reuses Orc")
	_check(lines, goblin != null and goblin.label() == "goblin" and goblin != party.bruiser, "Goblin resolves as itself")
	_check(lines, enemy == null, "Enemy with no qualifier is ambiguous")
	_check(lines, cycle == null, "cycle is rejected")
	_check(lines, factory != null and factory.made == 2, "one configuration instance builds sword and escort")
	_check(lines, bad != null and not _has_label(box, "BadFactory.missing_return_type"), "untyped factory method is not registered")
	_check(lines, music != null and music.get_parent() == get_tree().root and music.track == "town", "Node product is parented to the tree root")
	_check(lines, hud != null and hud.saw_clock and hud.get_parent() == get_tree().root, "Node _ready sees the injected clock")
	failed = false
	for line in lines:
		if String(line).begins_with("FAIL"):
			failed = true
			break
	_finish(lines, failed)


func _check(lines: PackedStringArray, passed: bool, text: String) -> void:
	lines.append("%s %s" % ["ok" if passed else "FAIL", text])


func _has_label(box: IOCContainer, label: String) -> bool:
	for definition in box.definitions:
		var product := definition as ComponentDefinition
		if product != null and product.label == label:
			return true
	return false


func _finish(lines: PackedStringArray, failed: bool) -> void:
	var text := "\n".join(lines)
	print(text)
	print("IOC_SLICE_FAIL" if failed else "IOC_SLICE_OK")
	if report != null:
		report.text = text
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if failed else 0)
