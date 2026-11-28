extends GutTest


func _mapper() -> Mapper:
	var mapper := Mapper.new()
	mapper.codec = JsonCodec.new()
	return mapper


func test_tower_save_roundtrip() -> void:
	var row := TdTowerSave.new()
	row.kind = "cannon"
	row.level = 2
	row.cell = Vector2i(3, 4)
	var loaded := _mapper().read(TdTowerSave, _mapper().write(row)) as TdTowerSave
	assert_not_null(loaded, "read")
	assert_eq(loaded.kind, "cannon", "kind")
	assert_eq(loaded.level, 2, "level")
	assert_eq(loaded.cell, Vector2i(3, 4), "cell")


func test_tower_save_requires_kind() -> void:
	var bytes := JSON.stringify({
		"_type": "TdTowerSave",
		"level": 1,
		"cell": {"_type": "Vector2i", "x": 0, "y": 0},
	}).to_utf8_buffer()
	assert_null(_mapper().read(TdTowerSave, bytes), "missing kind fails")
	assert_engine_error("TdTowerSave.kind is required.")


func test_field_packs_live_towers_on_write() -> void:
	var field := TdTowerField.new()
	var tower := TdTower.new()
	tower.kind = &"slow"
	tower.level = 3
	tower.cell = Vector2i(1, 2)
	field.live = [tower]
	var bytes := _mapper().write(field)
	assert_gt(bytes.size(), 0, "wrote")
	assert_eq(field.towers.size(), 1, "packed")
	var row := field.towers[0] as TdTowerSave
	assert_not_null(row, "row")
	assert_eq(row.kind, "slow", "kind packed")
	assert_eq(row.level, 3, "level packed")
	assert_eq(row.cell, Vector2i(1, 2), "cell packed")
	var text := bytes.get_string_from_utf8()
	assert_ne(text.find("\"kind\":\"slow\""), -1, "document has kind")
	assert_eq(text.find("\"live\""), -1, "live transient absent")
	tower.free()
