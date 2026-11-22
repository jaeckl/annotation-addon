class_name AopProxy
extends RefCounted

## Builds one subclass of a component script. Each advised method calls
## AopDispatch and then super, so the original body stays on the base script.
static var _names := RegEx.new()
static var _ready := false


static func defaults_ok(info: Dictionary) -> bool:
	var defaults: Array = info.get("default_args", [])
	for value in defaults:
		if _literal(value).is_empty():
			return false
	return true


static func build(target: GDScript, methods: Array) -> GDScript:
	var path := target.resource_path
	if path.is_empty() or methods.is_empty():
		return null
	var lines: PackedStringArray = PackedStringArray()
	lines.append("extends \"%s\"" % path.replace("\"", ""))
	lines.append("")
	lines.append("var __aop_chains: Dictionary = {}")
	lines.append("")
	for info in methods:
		var method_name := String(info.get("name", ""))
		if not _identifier(method_name):
			return null
		var rendered := _signature(info)
		if rendered.is_empty():
			return null
		var passed := _forward(info)
		var call := "AopDispatch.invoke(self, &\"%s\", [%s], Callable(self, &\"__aop_super_%s\"), __aop_chains)" % [method_name, passed, method_name]
		lines.append("func %s%s:" % [method_name, rendered])
		if _returns_void(info):
			lines.append("\t%s" % call)
		else:
			lines.append("\treturn %s" % call)
		lines.append("")
		lines.append("func __aop_super_%s(args: Array) -> Variant:" % method_name)
		if _returns_void(info):
			lines.append("\tsuper.%s(%s)" % [method_name, _super_args(info)])
			lines.append("\treturn null")
		else:
			lines.append("\treturn super.%s(%s)" % [method_name, _super_args(info)])
		lines.append("")
	var script := GDScript.new()
	script.source_code = "\n".join(lines)
	if script.reload() != OK:
		return null
	return script


static func render_body(info: Dictionary, source: String) -> String:
	var method_name := String(info.get("name", ""))
	if not _identifier(method_name) or not defaults_ok(info):
		return ""
	var rendered := _signature(info)
	var newline := source.find("\n")
	var body := source.substr(newline + 1) if newline >= 0 else ""
	var call := "AopDispatch.invoke(self, &\"%s\", [%s], Callable(self, &\"__aop_super_%s\"), __aop_chains)" % [method_name, _forward(info), method_name]
	var lines := PackedStringArray()
	lines.append("func %s%s:" % [method_name, rendered])
	if _returns_void(info):
		lines.append("\t%s" % call)
	else:
		lines.append("\treturn %s" % call)
	lines.append("")
	lines.append("func __aop_super_%s(args: Array) -> Variant:" % method_name)
	var args: Array = info.get("args", [])
	for index in args.size():
		var argument: Dictionary = args[index]
		var arg_name := String(argument.get("name", ""))
		if not _identifier(arg_name):
			arg_name = "arg%d" % index
		lines.append("\tvar %s = args[%d]" % [arg_name, index])
	for raw in body.split("\n"):
		lines.append(raw)
	if _returns_void(info):
		lines.append("\treturn null")
	lines.append("")
	return "\n".join(lines)


static func _signature(info: Dictionary) -> String:
	var args: Array = info.get("args", [])
	var defaults: Array = info.get("default_args", [])
	var first_default := args.size() - defaults.size()
	var parts: PackedStringArray = PackedStringArray()
	for index in args.size():
		var argument: Dictionary = args[index]
		var arg_name := String(argument.get("name", ""))
		if not _identifier(arg_name):
			arg_name = "arg%d" % index
		var piece := arg_name
		if index >= first_default:
			var literal := _literal(defaults[index - first_default])
			if literal.is_empty():
				return ""
			piece = "%s = %s" % [arg_name, literal]
		parts.append(piece)
	return "(%s)" % ", ".join(parts)


static func _forward(info: Dictionary) -> String:
	var args: Array = info.get("args", [])
	var parts: PackedStringArray = PackedStringArray()
	for index in args.size():
		var argument: Dictionary = args[index]
		var arg_name := String(argument.get("name", ""))
		if not _identifier(arg_name):
			arg_name = "arg%d" % index
		parts.append(arg_name)
	return ", ".join(parts)


static func _super_args(info: Dictionary) -> String:
	var args: Array = info.get("args", [])
	var parts: PackedStringArray = PackedStringArray()
	for index in args.size():
		parts.append("args[%d]" % index)
	return ", ".join(parts)


static func _returns_void(info: Dictionary) -> bool:
	var returned: Dictionary = info.get("return", {})
	if int(returned.get("type", TYPE_NIL)) != TYPE_NIL:
		return false
	return (int(returned.get("usage", 0)) & PROPERTY_USAGE_NIL_IS_VARIANT) == 0


static func _literal(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT, TYPE_FLOAT:
			if typeof(value) == TYPE_FLOAT and (is_nan(value) or is_inf(value)):
				return ""
			return var_to_str(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return var_to_str(value)
		_:
			return ""


static func _identifier(text: String) -> bool:
	if text.is_empty():
		return false
	if not _ready:
		_names.compile("^[A-Za-z_][A-Za-z0-9_]*$")
		_ready = true
	return _names.search(text) != null
