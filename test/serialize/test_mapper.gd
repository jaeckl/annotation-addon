extends GutTest


func _mapper() -> Mapper:
	var mapper := Mapper.new()
	mapper.codec = JsonCodec.new()
	return mapper


func _assert_hero(hero: SaveHero) -> void:
	assert_eq(hero.hp, 7, "hp")
	assert_eq(hero.name_label, "Bea", "renamed field")
	assert_eq(hero.secret, "no", "transient stays at the default")
	assert_eq(hero.mana, 4, "derived field")
	assert_eq(hero.ratio, 1.5, "float")
	assert_eq(hero.spot, Vector2(1.5, -2), "Vector2")
	assert_eq(hero.where, Vector3(1, 0, -3.5), "Vector3")
	assert_eq(hero.tint, Color(0.25, 0.5, 0.75, 1), "Color")
	assert_eq(hero.path, NodePath("Body/Hand"), "NodePath")
	assert_eq(hero.tag, StringName("hero"), "StringName")
	assert_eq(hero.flags, [1, true, "a"], "array")
	assert_eq(hero.meta, {"slot": "bag", "n": 2}, "dictionary")
	assert_not_null(hero.weapon, "nested object")
	assert_eq(hero.weapon.damage, 9, "nested field")
	assert_eq(hero.weapon.note, "hidden", "nested transient stays at the default")


func test_class_mark_roundtrips_through_json() -> void:
	var mapper := _mapper()
	var bytes := mapper.write(SaveHero.sample())
	var text := bytes.get_string_from_utf8()
	assert_eq(text.find("secret"), -1, "transient is absent")
	assert_eq(text.find("name_label"), -1, "the field name is not the key")
	assert_ne(text.find("\"title\""), -1, "the rename is the key")
	assert_eq(text.find("\"note\""), -1, "a nested transient is absent")
	var loaded := mapper.read(SaveHero, bytes) as SaveHero
	assert_not_null(loaded, "read returns the hero")
	_assert_hero(loaded)


func test_subclass_reads_as_the_base_class() -> void:
	var mapper := _mapper()
	var loaded := mapper.read(SavePlayer, mapper.write(SaveHero.sample())) as SaveHero
	assert_not_null(loaded, "a subclass document matches the base class")
	assert_eq(loaded.mana, 4, "the subclass field is restored")


func test_a_parent_document_does_not_match() -> void:
	var mapper := _mapper()
	var player := SavePlayer.new()
	player.hp = 3
	assert_null(mapper.read(SaveHero, mapper.write(player)), "the base is not the subclass")
	assert_engine_error("SavePlayer is not a SaveHero.")


func test_field_mark_saves_that_field_and_a_marked_object() -> void:
	var mapper := _mapper()
	var note := SaveNote.new()
	note.text = "hello"
	note.hidden = "changed"
	note.gem = SaveGem.new()
	note.gem.cut = "oval"
	note.gem.price = 9
	var bytes := mapper.write(note)
	var text := bytes.get_string_from_utf8()
	assert_eq(text.find("hidden"), -1, "an unmarked field is absent")
	assert_eq(text.find("price"), -1, "a nested transient is absent")
	var loaded := mapper.read(SaveNote, bytes) as SaveNote
	assert_eq(loaded.text, "hello", "the marked field")
	assert_eq(loaded.hidden, "x", "the unmarked field keeps its default")
	assert_eq(loaded.gem.cut, "oval", "the nested class mark is walked")
	assert_eq(loaded.gem.price, 1, "the nested transient keeps its default")
	assert_null(loaded.extra, "a null object stays null")


func test_a_field_object_without_a_class_mark_is_not_a_document() -> void:
	var mapper := _mapper()
	var note := SaveNote.new()
	note.extra = SavePlain.new()
	assert_eq(mapper.write(note).size(), 0, "write returns no bytes")
	assert_engine_error("SavePlain is not a document.")


func test_an_unmarked_class_is_not_a_document() -> void:
	var mapper := _mapper()
	assert_eq(mapper.write(SavePlain.new()).size(), 0, "write returns no bytes")
	assert_engine_error("SavePlain is not a document.")


func test_a_shared_reference_is_two_copies() -> void:
	var mapper := _mapper()
	var shared := SaveWeapon.new()
	shared.damage = 9
	var pair := SavePair.new()
	pair.left = shared
	pair.right = shared
	var loaded := mapper.read(SavePair, mapper.write(pair)) as SavePair
	assert_eq(loaded.left.damage, 9, "left copy")
	assert_eq(loaded.right.damage, 9, "right copy")
	assert_ne(loaded.left.get_instance_id(), loaded.right.get_instance_id(), "two objects")


func test_a_cycle_returns_no_bytes() -> void:
	var mapper := _mapper()
	var first := SaveLoop.new()
	var second := SaveLoop.new()
	first.other = second
	second.other = first
	assert_eq(mapper.write(first).size(), 0, "write returns no bytes")
	assert_engine_error("SaveLoop contains a cycle.")


func test_a_dictionary_key_must_be_a_string() -> void:
	var mapper := _mapper()
	var bag := SaveBag.new()
	bag.slots[1] = "a"
	assert_eq(mapper.write(bag).size(), 0, "write returns no bytes")
	assert_engine_error("a dictionary key must be a string.")


func test_a_dictionary_key_cannot_be_type() -> void:
	var mapper := _mapper()
	var bag := SaveBag.new()
	bag.slots["_type"] = "a"
	assert_eq(mapper.write(bag).size(), 0, "write returns no bytes")
	assert_engine_error("a dictionary key cannot be _type.")


func test_json_int_fills_a_float_field() -> void:
	var mapper := _mapper()
	var bytes := JSON.stringify({"_type": "SavePlayer", "ratio": 2}).to_utf8_buffer()
	var loaded := mapper.read(SavePlayer, bytes) as SavePlayer
	assert_not_null(loaded, "the document is read")
	assert_eq(loaded.ratio, 2.0, "the int becomes a float")
	assert_eq(typeof(loaded.ratio), TYPE_FLOAT, "the field stays a float")


func test_a_transient_field_in_the_file_is_rejected() -> void:
	var mapper := _mapper()
	var bytes := JSON.stringify({"_type": "SavePlayer", "secret": "x"}).to_utf8_buffer()
	assert_null(mapper.read(SavePlayer, bytes), "read returns null")
	assert_engine_error("SavePlayer.secret is transient.")


func test_an_unknown_field_is_rejected() -> void:
	var mapper := _mapper()
	var bytes := JSON.stringify({"_type": "SavePlayer", "nope": 1}).to_utf8_buffer()
	assert_null(mapper.read(SavePlayer, bytes), "read returns null")
	assert_engine_error("SavePlayer has no field nope.")


func test_an_unknown_type_is_rejected() -> void:
	var mapper := _mapper()
	var bytes := JSON.stringify({"_type": "MissingSave"}).to_utf8_buffer()
	assert_null(mapper.read(SavePlayer, bytes), "read returns null")
	assert_engine_error("MissingSave is not a class.")


func test_a_script_without_a_class_name_is_rejected() -> void:
	var mapper := _mapper()
	var bare: Object = load("res://test/serialize/save_bare.gd").new()
	assert_eq(mapper.write(bare).size(), 0, "write returns no bytes")
	assert_engine_error("save_bare.gd needs a class_name.")


func test_an_object_without_a_script_is_rejected() -> void:
	var mapper := _mapper()
	assert_eq(mapper.write(RefCounted.new()).size(), 0, "write returns no bytes")
	assert_engine_error("RefCounted has no script.")


func test_both_marks_on_one_field_are_rejected() -> void:
	var mapper := _mapper()
	assert_eq(mapper.write(SaveClash.new()).size(), 0, "write returns no bytes")
	assert_engine_error("SaveClash.hp is @Serialize and @Transient.")


func test_serialize_on_a_method_is_rejected() -> void:
	var mapper := _mapper()
	assert_eq(mapper.write(SaveMethod.new()).size(), 0, "write returns no bytes")
	assert_engine_error("@Serialize on SaveMethod belongs on a class or a field.")


func test_transient_on_a_class_is_rejected() -> void:
	var mapper := _mapper()
	assert_eq(mapper.write(SaveBadTransient.new()).size(), 0, "write returns no bytes")
	assert_engine_error("@Transient on SaveBadTransient belongs on a field.")


func test_a_class_mark_does_not_take_a_name() -> void:
	var mapper := _mapper()
	assert_eq(mapper.write(SaveNamed.new()).size(), 0, "write returns no bytes")
	assert_engine_error("a class mark on SaveNamed does not take a name.")


func test_a_field_named_type_is_rejected() -> void:
	var mapper := _mapper()
	assert_eq(mapper.write(SaveTypeField.new()).size(), 0, "write returns no bytes")
	assert_engine_error("SaveTypeField._type cannot be a field.")


func test_read_into_fills_an_existing_instance() -> void:
	var mapper := _mapper()
	var bytes := mapper.write(SaveHero.sample())
	var target := SaveHero.new()
	target.secret = "keep"
	assert_true(mapper.read_into(target, bytes), "read_into succeeds")
	assert_eq(target.hp, 7, "hp filled")
	assert_eq(target.name_label, "Bea", "renamed field filled")
	assert_eq(target.secret, "keep", "transient left alone")


func test_readable_accepts_a_matching_document() -> void:
	var mapper := _mapper()
	var bytes := mapper.write(SavePlayer.new())
	assert_true(mapper.readable(SavePlayer, bytes), "matching bytes are readable")


func test_readable_rejects_a_bad_document() -> void:
	var mapper := _mapper()
	var bytes := JSON.stringify({"_type": "SavePlayer", "nope": 1}).to_utf8_buffer()
	assert_false(mapper.readable(SavePlayer, bytes), "unknown field is not readable")
	assert_push_error("SavePlayer has no field nope.")
