class_name XmlCodec
extends Codec

## One element per value. t is n, b, i, d, s, a, o, or u. n is the dictionary
## key. c is the object _type. Text is escaped and is not trimmed.

var _bad := false


func write(document: Dictionary) -> PackedByteArray:
	return _write_value(document, "").to_utf8_buffer()


func read(bytes: PackedByteArray) -> Dictionary:
	_bad = false
	var parser := XMLParser.new()
	if parser.open_buffer(bytes) != OK:
		_fail("Serialize: XML could not be read.")
		return {}
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		var parsed := _parse_element(parser)
		if _bad or typeof(parsed["value"]) != TYPE_DICTIONARY:
			if not _bad:
				_fail("Serialize: XML did not contain a document.")
			return {}
		return parsed["value"]
	_fail("Serialize: XML could not be read.")
	return {}


func _write_value(value: Variant, field_name: String) -> String:
	if value == null:
		return _element("n", field_name, "", "")
	match typeof(value):
		TYPE_BOOL:
			return _element("b", field_name, "", "true" if value else "false")
		TYPE_INT:
			return _element("i", field_name, "", str(value))
		TYPE_FLOAT:
			return _element("d", field_name, "", str(value))
		TYPE_STRING:
			return _element("s", field_name, "", _escape(String(value)))
		TYPE_ARRAY:
			var inner := ""
			for item in value:
				inner += _write_value(item, "")
			return _element("a", field_name, "", inner)
		TYPE_DICTIONARY:
			var extra := ""
			var kind := "u"
			if value.has("_type"):
				kind = "o"
				extra = " c=\"%s\"" % _escape(String(value["_type"]))
			var inner := ""
			for key in value:
				if kind == "o" and String(key) == "_type":
					continue
				inner += _write_value(value[key], String(key))
			return _element(kind, field_name, extra, inner)
		_:
			return _element("n", field_name, "", "")


func _element(kind: String, field_name: String, extra: String, inner: String) -> String:
	var named := ""
	if field_name != "":
		named = " n=\"%s\"" % _escape(field_name)
	var attrs := " t=\"%s\"%s%s" % [kind, named, extra]
	if inner == "":
		return "<v%s/>" % attrs
	return "<v%s>%s</v>" % [attrs, inner]


func _escape(text: String) -> String:
	return text.replace("&", "&amp;").replace("\"", "&quot;").replace("<", "&lt;").replace(">", "&gt;")


func _parse_element(parser: XMLParser) -> Dictionary:
	var kind := parser.get_named_attribute_value_safe("t")
	var field_name := parser.get_named_attribute_value_safe("n")
	var type_name := parser.get_named_attribute_value_safe("c")
	if parser.is_empty():
		return {"name": field_name, "value": _scalar(kind, type_name, "", [])}
	var text := ""
	var children: Array = []
	while parser.read() == OK:
		var node_type := parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT_END:
			break
		if node_type == XMLParser.NODE_TEXT:
			text += parser.get_node_data()
			continue
		if node_type == XMLParser.NODE_ELEMENT:
			children.append(_parse_element(parser))
	return {"name": field_name, "value": _scalar(kind, type_name, text, children)}


func _scalar(kind: String, type_name: String, text: String, children: Array) -> Variant:
	match kind:
		"n":
			return null
		"b":
			if text != "true" and text != "false":
				_fail("Serialize: XML bool is invalid.")
				return false
			return text == "true"
		"i":
			return int(text)
		"d":
			return float(text)
		"s":
			return text
		"a":
			var items: Array = []
			for child in children:
				items.append(child["value"])
			return items
		"o":
			if type_name.is_empty():
				_fail("Serialize: XML object needs a type.")
				return {}
			var mapped := {"_type": type_name}
			for child in children:
				mapped[String(child["name"])] = child["value"]
			return mapped
		"u":
			var user := {}
			for child in children:
				user[String(child["name"])] = child["value"]
			return user
		_:
			_fail("Serialize: XML type %s is unknown." % kind)
			return null


func _fail(message: String) -> void:
	if _bad:
		return
	_bad = true
	push_error(message)
