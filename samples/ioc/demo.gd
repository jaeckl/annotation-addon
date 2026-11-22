extends Control

## Runs the app-scope slice and the scene enter-tree fill.
## This node is not a @Component. @onready below is only the report label.
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
	var camp := box.resolve(Camp) as Camp
	var spotter = $Spotter
	var planted := $PlantedHud as Hud
	await get_tree().process_frame
	var goblin := box.resolve(Goblin) as Goblin
	var enemy := box.resolve(Enemy)
	var cycle := box.resolve(LoopLeft)
	var factory := box.configuration(CombatFactory) as CombatFactory
	var bad := box.configuration(BadFactory)
	var bench := box.resolve(Bench) as Bench
	var wave := box.resolve(Wave) as Wave
	var bag := box.resolve(LoopBag)

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
	_check(lines, _same_members(party.enemies, [goblin, party.bruiser, party.boss, party.stalker]), "Array[Enemy] receives every enemy")
	_check(lines, party.offline_pack.size() == 1 and party.offline_pack[0] == party.stalker, "@Offline array keeps only Wolf")
	_check(lines, party.bosses.size() == 1 and party.bosses[0] == party.boss, "@Rank array keeps only Dragon")
	_check(lines, party.nobody.is_empty(), "qualifier with no match is an empty array")
	_check(lines, bench != null and _same_members(bench.enemies, party.enemies), "_init receives the enemy array")
	_check(lines, wave != null and wave.enemies.size() == 1 and wave.enemies[0] == party.stalker, "factory parameter receives the offline array")
	_check(lines, spotter.get("enemies") != null and _same_members(spotter.get("enemies"), party.enemies), "scene node receives the enemy array")
	_check(lines, cycle == null, "cycle is rejected")
	_check(lines, bag == null, "array member cycle is rejected")
	_check(lines, factory != null and factory.made == 4, "one configuration instance builds sword, escort, camp, and wave")
	_check(lines, bad != null and not _has_label(box, "BadFactory.missing_return_type"), "untyped factory method is not registered")
	_check(lines, not _has_label(box, "BadList"), "untyped Array is not registered")
	_check(lines, music != null and music.get_parent() == get_tree().root and music.track == "town", "Node product is parented to the tree root")
	_check(lines, hud != null and hud.saw_clock and hud.get_parent() == get_tree().root, "Node _ready sees the injected clock")
	_check(lines, spotter.get("clock") == party.clock and spotter.get("bruiser") == party.bruiser and spotter.get("boss") is Dragon and spotter.get("stalker") is Wolf, "scene node receives @Inject on enter")
	_check(lines, spotter.get("clock_ready") and spotter.get("badge_text") == "scout", "@onready runs after @Inject and still reads $Badge")
	_check(lines, planted.clock == null and not planted.saw_clock, "scene node that is also @Component is not filled")
	var lookout = camp.get_node("Lookout") if camp != null else null
	_check(lines, lookout != null and lookout.get("clock") == party.clock and lookout.get("clock_ready"), "factory scene child receives @Inject on enter")
	var settings := box.environment
	var music_track := _environment_music()
	var combat_title := _command_title()
	_check(lines, settings != null and _source_names(settings) == PackedStringArray(["command-line", "os-environment", "project-settings", "res://config/20-local.cfg", "res://config/10-defaults.cfg", "res://config/audio_defaults.tres"]), "command line, OS, and ProjectSettings sit above the cfg files")
	_check(lines, settings.contains("audio/master") and is_equal_approx(float(settings.get_value("audio/master")), 0.8), "later cfg file wins audio/master")
	_check(lines, settings.get_value("audio/music") == music_track, "OS environment overrides audio/music")
	_check(lines, int(settings.get_value("audio/channels")) == 6, "ProjectSettings overrides audio/channels")
	_check(lines, settings.get_value("combat/enabled") == true and settings.get_value("combat/title") == combat_title, "command line overrides combat/title")
	_check(lines, not settings.contains("audio/missing"), "absent key is missing")
	_check(lines, party.audio != null and party.audio == box.resolve(AudioSettings) and is_equal_approx(party.audio.master, 0.8) and party.audio.music == music_track and party.audio.channels == 6 and party.audio.subtitle == "from-tres" and party.audio.leaked == "keep", "@ConfigurationProperties keeps the winning value")
	_check(lines, party.combat_options != null and party.combat_options.enabled and party.combat_options.title == combat_title, "RefCounted settings keep the winning combat/title")
	_check(lines, _converter_order(box), "custom converter sits in front of the scalar converter")
	_check(lines, typeof(settings.get_value("audio/gain")) == TYPE_STRING and typeof(settings.get_value("audio/muted")) == TYPE_STRING and typeof(settings.get_value("audio/loops")) == TYPE_STRING and typeof(settings.get_value("audio/pace")) == TYPE_STRING, "quoted cfg values stay strings")
	_check(lines, party.audio != null and is_equal_approx(party.audio.gain, 1.5) and party.audio.muted == false and party.audio.loops == 3 and party.audio.pace == 2, "converters parse strings and the custom pace wins")
	var cached := load("res://config/audio_defaults.tres") as AudioSettings
	_check(lines, cached != null and cached != party.audio and is_equal_approx(cached.master, 0.1) and cached.subtitle == "from-tres" and settings.get_value("audio/subtitle") == "from-tres", ".tres supplies a missing key and the cached resource stays unchanged")
	_check(lines, not _has_label(box, "BadAudio"), "type mismatch is not published")
	_check(lines, not _has_label(box, "IgnoredSettings"), "settings outside the scan root are not registered")
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


func _same_members(list: Variant, expected: Array) -> bool:
	if list == null or not (list is Array) or list.size() != expected.size():
		return false
	for item in expected:
		if not list.has(item):
			return false
	return true


func _converter_order(box: IOCContainer) -> bool:
	var converters := box.binder.converters
	if converters.is_empty() or not (converters[converters.size() - 1] is ScalarPropertyConverter):
		return false
	for converter in converters:
		if converter is PaceConverter:
			return true
	return false


func _source_names(settings: PropertyEnvironment) -> PackedStringArray:
	var names := PackedStringArray()
	for source in settings.sources:
		var origin := source as PropertySource
		names.append(origin.source_name if origin != null else "")
	return names


func _environment_music() -> String:
	if OS.has_environment("AUDIO_MUSIC"):
		return OS.get_environment("AUDIO_MUSIC")
	return "town"


func _command_title() -> String:
	for argument in OS.get_cmdline_user_args():
		var text := String(argument)
		if text.begins_with("--combat/title="):
			return text.substr("--combat/title=".length())
	return "local"


func _finish(lines: PackedStringArray, failed: bool) -> void:
	var text := "\n".join(lines)
	print(text)
	print("IOC_SLICE_FAIL" if failed else "IOC_SLICE_OK")
	if report != null:
		report.text = text
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if failed else 0)
