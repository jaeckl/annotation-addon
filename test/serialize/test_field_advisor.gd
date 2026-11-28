extends GutTest


func _mapper() -> Mapper:
	var mapper := Mapper.new()
	mapper.codec = JsonCodec.new()
	return mapper


func test_an_advisor_rewrites_on_write_and_read() -> void:
	var mapper := _mapper()
	var mark := SaveMark.new()
	mark.score = 99
	var bytes := mapper.write(mark)
	assert_ne(bytes.size(), 0, "write succeeds after the rewrite")
	assert_ne(bytes.get_string_from_utf8().find("\"score\":5"), -1, "the document stores the rewritten value")
	assert_eq(mark.score, 99, "write does not change the live instance")
	var loaded := mapper.read(SaveMark, bytes) as SaveMark
	assert_not_null(loaded, "read succeeds")
	assert_eq(loaded.score, 5, "read keeps the rewritten document value")


func test_an_advisor_rejects_a_write() -> void:
	var mapper := _mapper()
	var mark := SaveMark.new()
	mark.score = -1
	assert_eq(mapper.write(mark).size(), 0, "write returns no bytes")
	assert_push_error("SaveMark.score score stays up")


func test_an_advisor_rejects_a_read_into() -> void:
	var mapper := _mapper()
	var good := SaveMark.new()
	good.score = 3
	var bytes := mapper.write(good)
	assert_ne(bytes.size(), 0, "a good write works")
	# Hand-build a document the advisor will refuse on the way in.
	var bad := JSON.stringify({"_type": "SaveMark", "score": -4}).to_utf8_buffer()
	var target := SaveMark.new()
	target.score = 8
	assert_false(mapper.read_into(target, bad), "read_into fails")
	assert_eq(target.score, 8, "a rejected read keeps the previous value")
	assert_push_error("SaveMark.score score stays up")


func test_a_broken_advisor_fails_the_write() -> void:
	var mapper := _mapper()
	var broken := SaveBreak.new()
	assert_eq(mapper.write(broken).size(), 0, "write returns no bytes")
	assert_push_error("SaveBreak.force_break advisor SaveMarkAdvisor returned no result")
