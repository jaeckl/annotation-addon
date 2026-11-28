extends GutTest


func _mapper() -> Mapper:
	var mapper := Mapper.new()
	mapper.codec = JsonCodec.new()
	return mapper


func test_tower_serialize_roundtrip() -> void:
	var tower := TdTower.new()
	tower.kind = &"cannon"
	tower.level = 2
	tower.cell = Vector2i(3, 4)
	var bytes := _mapper().write(tower)
	assert_gt(bytes.size(), 0, "wrote")
	var text := bytes.get_string_from_utf8()
	assert_ne(text.find("\"kind\""), -1, "kind key")
	assert_eq(text.find("selected"), -1, "transient absent")
	var loaded := _mapper().read(TdTower, bytes) as TdTower
	assert_not_null(loaded, "read")
	assert_eq(String(loaded.kind), "cannon", "kind")
	assert_eq(loaded.level, 2, "level")
	assert_eq(loaded.cell, Vector2i(3, 4), "cell")
	tower.free()
	loaded.free()


func test_tower_requires_kind() -> void:
	var bytes := JSON.stringify({
		"_type": "TdTower",
		"level": 1,
		"cell": {"_type": "Vector2i", "x": 0, "y": 0},
	}).to_utf8_buffer()
	assert_null(_mapper().read(TdTower, bytes), "missing kind fails")
	assert_engine_error("TdTower.kind is required.")


func test_field_writes_tower_array() -> void:
	var field := TdTowerField.new()
	var tower := TdTower.new()
	tower.kind = &"slow"
	tower.level = 3
	tower.cell = Vector2i(1, 2)
	field.towers = [tower]
	var bytes := _mapper().write(field)
	assert_gt(bytes.size(), 0, "wrote")
	var text := bytes.get_string_from_utf8()
	assert_ne(text.find("\"kind\""), -1, "nested kind")
	assert_ne(text.find("TdTower"), -1, "nested type")
	assert_eq(text.find("\"shots\""), -1, "shots transient")
	tower.free()
