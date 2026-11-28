extends GutTest


func _mapper() -> Mapper:
	var mapper := Mapper.new()
	mapper.codec = JsonCodec.new()
	return mapper


func test_before_runs_on_write_and_after_on_read() -> void:
	var mapper := _mapper()
	var src := SaveHooked.new()
	src.live = 9
	src.count = 0
	var bytes := mapper.write(src)
	assert_gt(bytes.size(), 0, "wrote")
	assert_eq(src.before_write_runs, 1, "before write")
	assert_eq(src.after_write_runs, 1, "after write")
	assert_eq(src.count, 9, "before packed live into count")
	var text := bytes.get_string_from_utf8()
	assert_ne(text.find("\"count\":9"), -1, "document has packed count")
	assert_eq(text.find("live"), -1, "transient absent")
	var loaded := mapper.read(SaveHooked, bytes) as SaveHooked
	assert_not_null(loaded, "read")
	assert_eq(loaded.count, 9, "count restored")
	assert_eq(loaded.live, 9, "after rebuilt live")
	assert_eq(loaded.before_read_runs, 1, "before read")
	assert_eq(loaded.after_read_runs, 1, "after read")


func test_read_into_runs_after() -> void:
	var mapper := _mapper()
	var src := SaveHooked.new()
	src.live = 4
	var bytes := mapper.write(src)
	var dest := SaveHooked.new()
	assert_true(mapper.read_into(dest, bytes), "read_into")
	assert_eq(dest.live, 4, "after on read_into")
	assert_eq(dest.before_read_runs, 1, "before once")
	assert_eq(dest.after_read_runs, 1, "after once")


func test_nested_hooks_run() -> void:
	var mapper := _mapper()
	var nest := SaveHookNest.new()
	nest.child = SaveHooked.new()
	nest.child.live = 3
	var written := mapper.write(nest)
	assert_eq(nest.child.after_write_runs, 1, "child after write")
	var loaded := mapper.read(SaveHookNest, written) as SaveHookNest
	assert_not_null(loaded, "nest read")
	assert_eq(loaded.child.live, 3, "child after")
	assert_eq(loaded.after_read_runs, 1, "parent after")
	assert_eq(loaded.child.after_read_runs, 1, "child after once")
	assert_eq(loaded.child.before_read_runs, 1, "child before read")


func test_hooks_must_be_methods() -> void:
	var mapper := _mapper()
	assert_eq(mapper.write(SaveHookBad.new()).size(), 0, "write fails")
	assert_engine_error("@OnBeforeSerialization on SaveHookBad belongs on a method.")


func test_hooks_must_take_nothing() -> void:
	var mapper := _mapper()
	assert_eq(mapper.write(SaveHookBadArgs.new()).size(), 0, "write fails")
	assert_engine_error("SaveHookBadArgs.bad_args @OnAfterDeserialization must take nothing.")
