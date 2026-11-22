class_name DirectoryBundle
extends RefCounted

## Writes one file per entry under a root directory.

var root: String = ""
var _names: Dictionary = {}
var _failed := false


func add(entry_name: String, data: PackedByteArray) -> void:
	if _failed:
		return
	if not _entry_ok(entry_name):
		return
	if root.is_empty():
		_error("Serialize: DirectoryBundle needs a root.")
		return
	if _names.has(entry_name):
		_error("Serialize: directory entry %s is duplicated." % entry_name)
		return
	var err := DirAccess.make_dir_recursive_absolute(root)
	if err != OK:
		_error("Serialize: directory %s could not be created." % root)
		return
	var path := root.path_join(entry_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Serialize: directory entry %s could not be written." % entry_name)
		return
	file.store_buffer(data)
	file.close()
	_names[entry_name] = true


func read(entry_name: String) -> PackedByteArray:
	if not _entry_ok(entry_name):
		return PackedByteArray()
	var path := root.path_join(entry_name)
	if not FileAccess.file_exists(path):
		_error("Serialize: directory entry %s is missing." % entry_name)
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)


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
