class_name BinaryCodec
extends Codec

## Little-endian tagged values. Magic is SRB1. Tags are null, bool, int64,
## float64, utf-8 string, array, and dictionary. An object document is a
## dictionary that contains _type.

const _MAGIC := "SRB1"
var _bad := false


func write(document: Dictionary) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.put_data(_MAGIC.to_utf8_buffer())
	_put_value(buf, document)
	return buf.data_array


func read(bytes: PackedByteArray) -> Dictionary:
	_bad = false
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.data_array = bytes
	if not _need(buf, 4):
		_fail("Serialize: binary ended early.")
		return {}
	var magic: Array = buf.get_data(4)
	if int(magic[0]) != OK or (magic[1] as PackedByteArray).get_string_from_utf8() != _MAGIC:
		_fail("Serialize: binary magic is wrong.")
		return {}
	var value: Variant = _get_value(buf)
	if _bad or typeof(value) != TYPE_DICTIONARY:
		if not _bad:
			_fail("Serialize: binary did not contain a document.")
		return {}
	return value


func _put_value(buf: StreamPeerBuffer, value: Variant) -> void:
	if value == null:
		buf.put_8(0)
		return
	match typeof(value):
		TYPE_BOOL:
			buf.put_8(1)
			buf.put_8(1 if value else 0)
		TYPE_INT:
			buf.put_8(2)
			buf.put_64(int(value))
		TYPE_FLOAT:
			buf.put_8(3)
			buf.put_double(float(value))
		TYPE_STRING:
			buf.put_8(4)
			buf.put_utf8_string(String(value))
		TYPE_ARRAY:
			buf.put_8(5)
			buf.put_32(value.size())
			for item in value:
				_put_value(buf, item)
		TYPE_DICTIONARY:
			buf.put_8(6)
			buf.put_32(value.size())
			for key in value:
				buf.put_utf8_string(String(key))
				_put_value(buf, value[key])
		_:
			buf.put_8(0)


func _get_value(buf: StreamPeerBuffer) -> Variant:
	if not _need(buf, 1):
		_fail("Serialize: binary ended early.")
		return null
	var tag := buf.get_8()
	match tag:
		0:
			return null
		1:
			if not _need(buf, 1):
				_fail("Serialize: binary ended early.")
				return null
			return buf.get_8() != 0
		2:
			if not _need(buf, 8):
				_fail("Serialize: binary ended early.")
				return null
			return buf.get_64()
		3:
			if not _need(buf, 8):
				_fail("Serialize: binary ended early.")
				return null
			return buf.get_double()
		4:
			return _get_string(buf)
		5:
			if not _need(buf, 4):
				_fail("Serialize: binary ended early.")
				return null
			var count := buf.get_32()
			if count < 0:
				_fail("Serialize: binary array is invalid.")
				return null
			var items: Array = []
			for _i in count:
				items.append(_get_value(buf))
				if _bad:
					return null
			return items
		6:
			if not _need(buf, 4):
				_fail("Serialize: binary ended early.")
				return null
			var size := buf.get_32()
			if size < 0:
				_fail("Serialize: binary dictionary is invalid.")
				return null
			var mapped := {}
			for _i in size:
				var key := _get_string(buf)
				if _bad:
					return null
				mapped[key] = _get_value(buf)
				if _bad:
					return null
			return mapped
		_:
			_fail("Serialize: binary type %s is unknown." % tag)
			return null


func _get_string(buf: StreamPeerBuffer) -> String:
	if not _need(buf, 4):
		_fail("Serialize: binary ended early.")
		return ""
	var length := buf.get_32()
	if length < 0 or not _need(buf, length):
		_fail("Serialize: binary string is invalid.")
		return ""
	return buf.get_utf8_string(length)


func _need(buf: StreamPeerBuffer, count: int) -> bool:
	return buf.get_position() + count <= buf.get_size()


func _fail(message: String) -> void:
	if _bad:
		return
	_bad = true
	push_error(message)
