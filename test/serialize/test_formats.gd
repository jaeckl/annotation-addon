extends GutTest


func _assert_hero(hero: SaveHero) -> void:
	assert_eq(hero.hp, 7, "hp")
	assert_eq(hero.name_label, "Bea", "renamed field")
	assert_eq(hero.secret, "no", "transient")
	assert_eq(hero.mana, 4, "mana")
	assert_eq(hero.ratio, 1.5, "float")
	assert_eq(hero.spot, Vector2(1.5, -2), "Vector2")
	assert_eq(hero.where, Vector3(1, 0, -3.5), "Vector3")
	assert_eq(hero.tint, Color(0.25, 0.5, 0.75, 1), "Color")
	assert_eq(hero.path, NodePath("Body/Hand"), "NodePath")
	assert_eq(hero.tag, StringName("hero"), "StringName")
	assert_eq(hero.flags, [1, true, "a"], "array")
	assert_eq(hero.meta, {"slot": "bag", "n": 2}, "dictionary")
	assert_eq(hero.weapon.damage, 9, "nested field")
	assert_eq(hero.weapon.note, "hidden", "nested transient")


func _roundtrip(codec: Codec) -> SaveHero:
	var mapper := Mapper.new()
	mapper.codec = codec
	var bytes := mapper.write(SaveHero.sample())
	assert_gt(bytes.size(), 0, "%s wrote bytes" % codec.get_class())
	return mapper.read(SaveHero, bytes) as SaveHero


func test_xml_roundtrips_the_same_document() -> void:
	var loaded := _roundtrip(XmlCodec.new())
	assert_not_null(loaded, "xml read")
	_assert_hero(loaded)


func test_binary_roundtrips_the_same_document() -> void:
	var loaded := _roundtrip(BinaryCodec.new())
	assert_not_null(loaded, "binary read")
	_assert_hero(loaded)


func test_the_three_codecs_use_different_bytes() -> void:
	var sample := SaveHero.sample()
	var json := _bytes(JsonCodec.new(), sample)
	var xml := _bytes(XmlCodec.new(), sample)
	var binary := _bytes(BinaryCodec.new(), sample)
	assert_eq(json.get_string_from_utf8().substr(0, 1), "{", "json object")
	assert_eq(xml.get_string_from_utf8().substr(0, 2), "<v", "xml element")
	assert_eq(binary.slice(0, 4).get_string_from_utf8(), "SRB1", "binary magic")


func test_xml_keeps_a_string_that_looks_like_markup() -> void:
	var mapper := Mapper.new()
	mapper.codec = XmlCodec.new()
	var note := SaveNote.new()
	note.text = " <a&b> "
	var loaded := mapper.read(SaveNote, mapper.write(note)) as SaveNote
	assert_eq(loaded.text, " <a&b> ", "the string is not trimmed or unescaped twice")


func test_bad_json_is_rejected() -> void:
	var mapper := Mapper.new()
	mapper.codec = JsonCodec.new()
	assert_null(mapper.read(SavePlayer, "nope".to_utf8_buffer()), "read returns null")
	assert_engine_error("JSON did not contain a document.")


func test_bad_binary_magic_is_rejected() -> void:
	var mapper := Mapper.new()
	mapper.codec = BinaryCodec.new()
	assert_null(mapper.read(SavePlayer, "XXXX".to_utf8_buffer()), "read returns null")
	assert_engine_error("binary magic is wrong.")


func _bytes(codec: Codec, instance: Object) -> PackedByteArray:
	var mapper := Mapper.new()
	mapper.codec = codec
	return mapper.write(instance)
