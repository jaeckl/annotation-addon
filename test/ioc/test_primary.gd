extends GutTest

var box: IOCContainer
var scan_errors: PackedStringArray = PackedStringArray()


func before_each() -> void:
	ProjectSettings.set_setting("ioc/primary_fixtures", "")
	ProjectSettings.set_setting("ioc/primary_clash", "")
	ProjectSettings.set_setting("ioc/primary_factory", "")
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	scan_errors = PackedStringArray()
	for err in get_errors():
		if err.handled:
			continue
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("Primary") != -1:
			scan_errors.append(text)
		err.handled = true


func after_each() -> void:
	ProjectSettings.set_setting("ioc/primary_fixtures", "")
	ProjectSettings.set_setting("ioc/primary_clash", "")
	ProjectSettings.set_setting("ioc/primary_factory", "")
	if box != null:
		box.shutdown()
	box = null
	await get_tree().process_frame


func test_primary_wins_when_several_match() -> void:
	_reboot({"ioc/primary_fixtures": "yes"})
	var picked := box.resolve(PrimaryKind) as PrimaryKind
	assert_not_null(picked, "one primary product is enough")
	assert_true(picked is PrimaryPick, "the @Primary product is chosen")
	assert_eq(picked.tag(), "pick")


func test_qualifier_still_picks_a_non_primary() -> void:
	_reboot({"ioc/primary_fixtures": "yes"})
	var picked := box.resolve(PrimaryKind, [_qualifier("plain")]) as PrimaryKind
	assert_not_null(picked, "the qualifier finds one")
	assert_true(picked is PrimaryPlain, "the qualifier wins over @Primary")
	assert_eq(picked.tag(), "plain")


func test_a_collection_still_returns_every_match() -> void:
	_reboot({"ioc/primary_fixtures": "yes"})
	var bag := box.resolve(PrimaryBag) as PrimaryBag
	assert_not_null(bag, "the bag builds")
	assert_eq(bag.kinds.size(), 2, "Array injection keeps every match")
	var tags: PackedStringArray = PackedStringArray()
	for item in bag.kinds:
		tags.append((item as PrimaryKind).tag())
	tags.sort()
	assert_eq(tags, PackedStringArray(["pick", "plain"]), "primary does not drop the other product")


func test_several_primaries_still_fail() -> void:
	_reboot({"ioc/primary_fixtures": "yes", "ioc/primary_clash": "yes"})
	var picked := box.resolve(PrimaryKind)
	assert_null(picked, "two @Primary products stay ambiguous")
	assert_push_error("several components for PrimaryKind")


func test_a_primary_factory_wins() -> void:
	_reboot({"ioc/primary_factory": "yes"})
	var picked := box.resolve(PrimaryKind) as PrimaryKind
	assert_not_null(picked, "the factory product is chosen")
	assert_true(picked is PrimaryMade, "the @Primary factory wins over PrimarySpare")
	assert_eq(picked.tag(), "made")


func test_bad_marks_are_rejected() -> void:
	assert_true(_has("PrimaryBadPlain is @Primary without @Component."), "the mark needs a product")
	assert_true(_has("@Primary on PrimaryBadMember belongs on a class or a factory method."), "a field is refused")
	assert_true(_has("PrimaryBadMember.ping is @Primary and is not a factory method."), "a plain method is refused")
	assert_true(_has("PrimaryBadConfig is @Primary on a configuration. Mark the factory method."), "a configuration class is refused")


func _reboot(settings: Dictionary) -> void:
	box.shutdown()
	box = null
	for key in settings.keys():
		ProjectSettings.set_setting(String(key), settings[key])
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	for err in get_errors():
		err.handled = true


func _qualifier(text: String) -> Qualifier:
	return AnnotationUtils.instantiate_annotation({
		"name": "Qualifier",
		"values": {"value": text},
	}) as Qualifier


func _has(needle: String) -> bool:
	for text in scan_errors:
		if text.find(needle) != -1:
			return true
	return false
