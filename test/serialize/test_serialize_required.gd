extends GutTest


func _mapper() -> Mapper:
	var mapper := Mapper.new()
	mapper.codec = JsonCodec.new()
	return mapper


func test_required_present_and_optional_absent() -> void:
	var mapper := _mapper()
	var bytes := JSON.stringify({
		"_type": "SaveRequired",
		"hp": 7,
		"score": 3,
	}).to_utf8_buffer()
	var loaded := mapper.read(SaveRequired, bytes) as SaveRequired
	assert_not_null(loaded, "read")
	assert_eq(loaded.hp, 7, "required filled")
	assert_eq(loaded.name_label, "Ada", "optional kept default")
	assert_eq(loaded.score, 3, "unmarked optional filled")


func test_required_missing_fails() -> void:
	var mapper := _mapper()
	var bytes := JSON.stringify({
		"_type": "SaveRequired",
		"score": 1,
	}).to_utf8_buffer()
	assert_null(mapper.read(SaveRequired, bytes), "read fails")
	assert_engine_error("SaveRequired.hp is required.")


func test_required_and_optional_clash() -> void:
	var mapper := _mapper()
	assert_eq(mapper.write(SaveRequiredClash.new()).size(), 0, "write fails")
	assert_engine_error("SaveRequiredClash.hp is @Required and @Optional.")


func test_field_mode_required() -> void:
	var mapper := _mapper()
	var src := SaveRequiredField.new()
	src.hp = 5
	src.bonus = 2
	var loaded := mapper.read(SaveRequiredField, mapper.write(src)) as SaveRequiredField
	assert_not_null(loaded, "round trip")
	assert_eq(loaded.hp, 5, "hp")
	assert_eq(loaded.bonus, 2, "bonus")
	var bytes := JSON.stringify({"_type": "SaveRequiredField", "bonus": 9}).to_utf8_buffer()
	assert_null(mapper.read(SaveRequiredField, bytes), "missing required")
	assert_engine_error("SaveRequiredField.hp is required.")
