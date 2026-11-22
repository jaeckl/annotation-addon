class_name ZipBundle
extends RefCounted

## Packs named entries into one deflate zip and writes that blob to a sink.
## ZIPPacker only opens a file path, so the packer uses a temp file under user://.

var sink: Sink
var _entries: Dictionary = {}
var _failed := false


func add(entry_name: String, data: PackedByteArray) -> void:
	if _failed:
		return
	if not _entry_ok(entry_name):
		return
	if _entries.has(entry_name):
		_error("Serialize: zip entry %s is duplicated." % entry_name)
		return
	_entries[entry_name] = data


func finish() -> void:
	if _failed:
		return
	if sink == null:
		_error("Serialize: ZipBundle needs a sink.")
		return
	var packed := _pack()
	if _failed:
		return
	sink.write(packed)


static func read_entries(data: PackedByteArray) -> Dictionary:
	var path := _temp_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Serialize: zip could not be read.")
		return {}
	file.store_buffer(data)
	file.close()
	var reader := ZIPReader.new()
	var err := reader.open(path)
	var found := {}
	if err != OK:
		push_error("Serialize: zip could not be read.")
	else:
		for entry_name in reader.get_files():
			if String(entry_name).ends_with("/"):
				continue
			found[String(entry_name)] = reader.read_file(entry_name)
		reader.close()
	_remove(path)
	return found


func _pack() -> PackedByteArray:
	var path := _temp_path()
	var packer := ZIPPacker.new()
	var err := packer.open(path)
	if err != OK:
		_error("Serialize: zip could not be packed.")
		return PackedByteArray()
	packer.compression_level = ZIPPacker.COMPRESSION_DEFAULT
	for entry_name in _entries:
		err = packer.start_file(String(entry_name))
		if err != OK:
			_error("Serialize: zip entry %s could not be packed." % entry_name)
			break
		err = packer.write_file(_entries[entry_name])
		if err != OK:
			_error("Serialize: zip entry %s could not be packed." % entry_name)
			break
		err = packer.close_file()
		if err != OK:
			_error("Serialize: zip entry %s could not be packed." % entry_name)
			break
	packer.close()
	var packed := PackedByteArray()
	if not _failed:
		packed = FileAccess.get_file_as_bytes(path)
	_remove(path)
	if _failed:
		return PackedByteArray()
	return packed


func _entry_ok(entry_name: String) -> bool:
	if entry_name.is_empty() or entry_name == "." or entry_name == ".." or entry_name.contains("..") or entry_name.contains("/") or entry_name.contains("\\"):
		_error("Serialize: entry %s is not a file name." % entry_name)
		return false
	return true


func _error(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)


static func _temp_path() -> String:
	return "user://serialize_%s_%s.zip" % [Time.get_ticks_usec(), randi()]


static func _remove(path: String) -> void:
	var dir := DirAccess.open(path.get_base_dir())
	if dir != null:
		dir.remove(path.get_file())
