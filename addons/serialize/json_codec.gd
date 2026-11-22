class_name JsonCodec
extends Codec

## JSON document codec. Uses Godot's JSON parser. A whole float may come back
## as an int; the mapper coerces it when the field type is float.


func write(document: Dictionary) -> PackedByteArray:
	return JSON.stringify(document).to_utf8_buffer()


func read(bytes: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("Serialize: JSON did not contain a document.")
		return {}
	return _whole_numbers(json.data)


func _whole_numbers(value: Variant) -> Variant:
	var kind := typeof(value)
	if kind == TYPE_FLOAT:
		var number := float(value)
		if is_finite(number) and number == floor(number) and abs(number) <= 9007199254740992.0:
			return int(number)
		return value
	if kind == TYPE_ARRAY:
		var items: Array = []
		for item in value:
			items.append(_whole_numbers(item))
		return items
	if kind == TYPE_DICTIONARY:
		var mapped := {}
		for key in value:
			mapped[key] = _whole_numbers(value[key])
		return mapped
	return value
