class_name MemorySink
extends Sink

## Keeps the last byte blob in memory.

var bytes := PackedByteArray()


func write(data: PackedByteArray) -> void:
	bytes = data


func read() -> PackedByteArray:
	return bytes
