extends GutTest

var _paths: PackedStringArray = PackedStringArray()


func after_each() -> void:
	for path in _paths:
		_wipe(path)
	_paths = PackedStringArray()


func test_memory_sink_keeps_the_bytes() -> void:
	var sink := MemorySink.new()
	var data := "abc".to_utf8_buffer()
	sink.write(data)
	assert_eq(sink.read(), data, "the same bytes come back")


func test_file_sink_roundtrips_mapper_bytes() -> void:
	var path := "user://serialize_file_%s.bin" % Time.get_ticks_usec()
	_paths.append(path)
	var mapper := Mapper.new()
	mapper.codec = JsonCodec.new()
	var written := mapper.write(SaveHero.sample())
	var sink := FileSink.new()
	sink.path = path
	sink.write(written)
	var again := FileSink.new()
	again.path = path
	var loaded := mapper.read(SaveHero, again.read()) as SaveHero
	assert_eq(loaded.hp, 7, "the file held the document")
	assert_eq(loaded.name_label, "Bea", "the renamed field survived the file")


func test_zip_bundle_roundtrips_two_entries() -> void:
	var raw := PackedByteArray()
	raw.resize(4000)
	raw.fill(97)
	var mapper := Mapper.new()
	mapper.codec = JsonCodec.new()
	var document := mapper.write(SaveNote.new())
	var sink := MemorySink.new()
	var bundle := ZipBundle.new()
	bundle.sink = sink
	bundle.add("note.json", document)
	bundle.add("pad.bin", raw)
	bundle.finish()
	var packed := sink.read()
	assert_gt(packed.size(), 0, "the zip has bytes")
	assert_lt(packed.size(), raw.size(), "deflate shrinks the pad")
	var entries := ZipBundle.read_entries(packed)
	assert_eq(entries["note.json"], document, "the document entry")
	assert_eq(entries["pad.bin"], raw, "the pad entry")
	var path := "user://serialize_level_%s.zip" % Time.get_ticks_usec()
	_paths.append(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(packed)
	file.close()
	var reader := ZIPReader.new()
	assert_eq(reader.open(path), OK, "the zip opens")
	assert_eq(reader.get_compression_level("pad.bin"), 6, "deflate level 6")
	reader.close()


func test_a_duplicate_zip_entry_is_rejected() -> void:
	var sink := MemorySink.new()
	var bundle := ZipBundle.new()
	bundle.sink = sink
	bundle.add("a.bin", PackedByteArray())
	bundle.add("a.bin", PackedByteArray())
	bundle.finish()
	assert_eq(sink.read().size(), 0, "finish writes nothing")
	assert_engine_error("zip entry a.bin is duplicated.")


func test_a_zip_entry_cannot_climb() -> void:
	var bundle := ZipBundle.new()
	bundle.add("..", PackedByteArray())
	assert_engine_error("entry .. is not a file name.")


func test_directory_bundle_writes_one_file_per_entry() -> void:
	var root := "user://serialize_dir_%s" % Time.get_ticks_usec()
	_paths.append(root)
	var bundle := DirectoryBundle.new()
	bundle.root = root
	bundle.add("note.json", "hi".to_utf8_buffer())
	bundle.add("pad.bin", "pad".to_utf8_buffer())
	var again := DirectoryBundle.new()
	again.root = root
	assert_eq(again.read("note.json").get_string_from_utf8(), "hi", "note file")
	assert_eq(again.read("pad.bin").get_string_from_utf8(), "pad", "pad file")


func test_a_duplicate_directory_entry_is_rejected() -> void:
	var root := "user://serialize_dir_%s" % Time.get_ticks_usec()
	_paths.append(root)
	var bundle := DirectoryBundle.new()
	bundle.root = root
	bundle.add("a.bin", "one".to_utf8_buffer())
	bundle.add("a.bin", "two".to_utf8_buffer())
	assert_engine_error("directory entry a.bin is duplicated.")
	assert_eq(bundle.read("a.bin").get_string_from_utf8(), "one", "the first file stays")


func _wipe(path: String) -> void:
	if FileAccess.file_exists(path):
		var parent := DirAccess.open(path.get_base_dir())
		if parent != null:
			parent.remove(path.get_file())
		return
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		if entry_name != "." and entry_name != "..":
			if dir.current_is_dir():
				_wipe(path.path_join(entry_name))
			else:
				dir.remove(entry_name)
		entry_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
