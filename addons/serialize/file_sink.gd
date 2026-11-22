class_name FileSink
extends Sink

## Reads and writes one file. The path is chosen by the caller.

var path: String = ""


func write(data: PackedByteArray) -> void:
	if path.is_empty():
		push_error("Serialize: FileSink needs a path.")
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Serialize: FileSink could not open %s." % path)
		return
	file.store_buffer(data)
	file.close()


func read() -> PackedByteArray:
	if path.is_empty():
		push_error("Serialize: FileSink needs a path.")
		return PackedByteArray()
	if not FileAccess.file_exists(path):
		push_error("Serialize: FileSink could not open %s." % path)
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)
