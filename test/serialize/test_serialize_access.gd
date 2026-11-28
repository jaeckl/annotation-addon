extends GutTest


func _mapper() -> Mapper:
	var mapper := Mapper.new()
	mapper.codec = JsonCodec.new()
	return mapper


func test_read_only_writes_write_only_omitted() -> void:
	var mapper := _mapper()
	var src := SaveAccess.new()
	src.stamp = "v1"
	src.secret = "s3cret"
	src.hp = 4
	var text := mapper.write(src).get_string_from_utf8()
	assert_ne(text.find("\"stamp\":\"v1\""), -1, "read_only written")
	assert_ne(text.find("\"hp\":4"), -1, "normal written")
	assert_eq(text.find("secret"), -1, "write_only omitted")


func test_write_only_fills_read_only_keeps() -> void:
	var mapper := _mapper()
	var bytes := JSON.stringify({
		"_type": "SaveAccess",
		"stamp": "from-disk",
		"secret": "inbox",
		"hp": 8,
	}).to_utf8_buffer()
	var loaded := mapper.read(SaveAccess, bytes) as SaveAccess
	assert_not_null(loaded, "read")
	assert_eq(loaded.stamp, "built", "read_only kept construct")
	assert_eq(loaded.secret, "inbox", "write_only filled")
	assert_eq(loaded.hp, 8, "normal filled")


func test_read_only_and_write_only_clash() -> void:
	var mapper := _mapper()
	assert_eq(mapper.write(SaveAccessClash.new()).size(), 0, "write fails")
	assert_engine_error("SaveAccessClash.hp is @ReadOnly and @WriteOnly.")
