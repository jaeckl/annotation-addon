class_name PropertyWeaver
extends RefCounted

## Reads a script and returns the same source with a getter and a setter on
## each @Property. The container reloads that script. A subclass cannot
## redeclare the field, so the setter has to live on the original script.


static func prepare(script: GDScript) -> Dictionary:
	if script == null or not _has_property(script):
		return {}
	var source := script.source_code.replace("\r\n", "\n")
	if source.is_empty():
		var path := script.resource_path
		if path.is_empty() or not FileAccess.file_exists(path):
			return {"error": "MVC: %s properties could not be read." % _name(script)}
		source = FileAccess.get_file_as_string(path).replace("\r\n", "\n")
	var lines := source.split("\n")
	var names := _property_names(script)
	if not String(names.get("error", "")).is_empty():
		return {"error": String(names["error"])}
	var properties: Array = names["names"]
	var methods := _methods(lines)
	var init_body := String(methods.get("_init", ""))
	var pending := 0
	for property_name in properties:
		var label := String(property_name)
		if _assigns(init_body, label):
			return {"error": "MVC: %s.%s is assigned in _init." % [_name(script), label]}
		if _has_setter(lines, label):
			if not _generated(lines, label):
				return {"error": "MVC: %s.%s already has a setter." % [_name(script), label]}
		elif _declaration(lines, label).is_empty():
			return {"error": "MVC: %s.%s could not be read." % [_name(script), label]}
		else:
			pending += 1
	if pending == 0:
		return {}
	return {"source": _rewrite(lines, properties)}


static func _has_property(script: GDScript) -> bool:
	var current := script
	while current != null:
		var bucket := {"found": false}
		AnnotationUtils.for_each_annotation_initialized(Property, current, func(_annotation: Object, _target: Object) -> void:
			bucket["found"] = true
		)
		if bool(bucket["found"]) or AnnotationUtils.has_annotation(current, Property):
			return true
		current = current.get_base_script()
	return false


static func _property_names(script: GDScript) -> Dictionary:
	var bucket := {"names": [], "error": ""}
	var current := script
	while current != null and String(bucket["error"]).is_empty():
		var label := _name(current)
		AnnotationUtils.for_each_annotation_initialized(Property, current, _take_property.bind(bucket, label))
		current = current.get_base_script()
	if not String(bucket["error"]).is_empty():
		return {"error": String(bucket["error"])}
	return {"names": bucket["names"]}


static func _take_property(_annotation: Object, target: Object, bucket: Dictionary, label: String) -> void:
	if not String(bucket["error"]).is_empty():
		return
	if not (target is VariableInfo):
		bucket["error"] = "MVC: @Property on %s belongs on a field." % label
		return
	var info := target as VariableInfo
	if info.is_static:
		bucket["error"] = "MVC: %s.%s is static and cannot be a property." % [label, info.name]
		return
	var names: Array = bucket["names"]
	names.append(String(info.name))


static func _declaration(lines: PackedStringArray, property_name: String) -> String:
	var prefix := "var %s" % property_name
	for line in lines:
		if not line.begins_with(prefix):
			continue
		var rest := line.substr(prefix.length())
		if not rest.is_empty() and _ident(rest.substr(0, 1)):
			continue
		var trimmed := line.strip_edges()
		var comment := trimmed.find(" #")
		if comment >= 0:
			trimmed = trimmed.substr(0, comment).strip_edges()
		if trimmed.ends_with(":"):
			return ""
		return trimmed
	return ""


static func _generated(lines: PackedStringArray, property_name: String) -> bool:
	return _block(lines, property_name).find("PropNotify.changed") >= 0


static func _rewrite(lines: PackedStringArray, properties: Array) -> String:
	var output := PackedStringArray()
	var index := 0
	while index < lines.size():
		var property_name := _line_property(lines[index], properties)
		if property_name.is_empty():
			output.append(lines[index])
			index += 1
			continue
		if _has_setter(lines, property_name):
			output.append(lines[index])
			index += 1
			while index < lines.size() and _continues(lines[index]):
				output.append(lines[index])
				index += 1
			continue
		var declaration := _declaration(lines, property_name)
		output.append(_accessor(declaration, property_name))
		index += 1
	return "\n".join(output)


static func _line_property(line: String, properties: Array) -> String:
	for property_name in properties:
		var label := String(property_name)
		var prefix := "var %s" % label
		if not line.begins_with(prefix):
			continue
		var rest := line.substr(prefix.length())
		if rest.is_empty() or not _ident(rest.substr(0, 1)):
			return label
	return ""


static func _continues(line: String) -> bool:
	return line.strip_edges().is_empty() or line.begins_with("\t") or line.begins_with(" ")


static func _block(lines: PackedStringArray, property_name: String) -> String:
	var prefix := "var %s" % property_name
	for index in lines.size():
		var line := lines[index]
		if not line.begins_with(prefix):
			continue
		var rest := line.substr(prefix.length())
		if not rest.is_empty() and _ident(rest.substr(0, 1)):
			continue
		var block := PackedStringArray()
		var cursor := index + 1
		while cursor < lines.size() and _continues(lines[cursor]):
			block.append(lines[cursor])
			cursor += 1
		return "\n".join(block)
	return ""


static func _has_setter(lines: PackedStringArray, property_name: String) -> bool:
	var prefix := "var %s" % property_name
	for index in lines.size():
		var line := lines[index]
		if not line.begins_with(prefix):
			continue
		var rest := line.substr(prefix.length())
		if not rest.is_empty() and _ident(rest.substr(0, 1)):
			continue
		var cursor := index + 1
		while cursor < lines.size():
			var next := lines[cursor]
			if next.strip_edges().is_empty():
				cursor += 1
				continue
			if not next.begins_with("\t") and not next.begins_with(" "):
				return false
			var text := next.strip_edges()
			if text.begins_with("set(") or text.begins_with("set "):
				return true
			cursor += 1
		return false
	return false


static func _accessor(declaration: String, property_name: String) -> String:
	var lines := PackedStringArray()
	lines.append("%s:" % declaration)
	lines.append("\tset(__next):")
	lines.append("\t\tvar accepted: Dictionary = PropNotify.accept(self, &\"%s\", __next, %s)" % [property_name, property_name])
	lines.append("\t\tif not bool(accepted.get(\"ok\", false)):")
	lines.append("\t\t\treturn")
	lines.append("\t\t%s = accepted.value" % property_name)
	lines.append("\t\tPropNotify.changed(self, &\"%s\", accepted.value)" % property_name)
	lines.append("\tget:")
	lines.append("\t\tPropNotify.read(self, &\"%s\")" % property_name)
	lines.append("\t\treturn %s" % property_name)
	return "\n".join(lines)


static func _methods(lines: PackedStringArray) -> Dictionary:
	var found := {}
	var index := 0
	while index < lines.size():
		var line := lines[index]
		var is_static := line.begins_with("static func ")
		var is_func := line.begins_with("func ") or is_static
		if not is_func:
			index += 1
			continue
		var block := PackedStringArray()
		block.append(line)
		index += 1
		while index < lines.size():
			var next := lines[index]
			if next.strip_edges().is_empty():
				block.append(next)
				index += 1
				continue
			if not next.begins_with("\t") and not next.begins_with(" "):
				break
			block.append(next)
			index += 1
		if is_static:
			continue
		var name := _func_name(line)
		if name.is_empty():
			continue
		found[name] = "\n".join(block).strip_edges()
	return found


static func _func_name(line: String) -> String:
	var text := line
	if text.begins_with("static "):
		text = text.substr(7)
	if not text.begins_with("func "):
		return ""
	text = text.substr(5).strip_edges()
	var end := 0
	while end < text.length() and _ident(text.substr(end, 1)):
		end += 1
	return text.substr(0, end)


static func _assigns(body: String, property_name: String) -> bool:
	for raw in body.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var index := 0
		while index < line.length():
			var found := line.find(property_name, index)
			if found < 0:
				break
			var after := found + property_name.length()
			var before_ok := found == 0 or not _ident(line.substr(found - 1, 1))
			var after_ok := after >= line.length() or not _ident(line.substr(after, 1))
			if before_ok and after_ok:
				var rest := line.substr(after).strip_edges()
				if rest.begins_with("+=") or rest.begins_with("-=") or rest.begins_with("*=") or rest.begins_with("/="):
					return true
				if rest.begins_with("=") and not rest.begins_with("=="):
					return true
			index = after if after > found else found + 1
	return false


static func _ident(text: String) -> bool:
	if text.is_empty():
		return false
	var code := text.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95


static func _name(script: GDScript) -> String:
	var global_name := script.get_global_name()
	if global_name != &"":
		return String(global_name)
	return script.resource_path.get_file().get_basename()
