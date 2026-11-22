class_name AnnotationReflect
extends Node

## Walks one script with AnnotationUtils.for_each_annotation_initialized.
## Each callback gets the annotation object and a ReflectionUtils view:
## ScriptInfo, VariableInfo, FunctionInfo, or ParameterInfo.


func _ready() -> void:
	var host := get_parent()
	if host == null:
		return
	var script := host.get_script() as GDScript
	if script == null:
		return
	var text := describe(script)
	print(text)
	var output := get_node_or_null("Output") as Label
	if output != null:
		output.text = text


static func describe(script: GDScript) -> String:
	var collector := _Collector.new()
	AnnotationUtils.for_each_annotation_initialized(SampleNote, script, collector.collect)
	return "\n".join(collector.lines)


class _Collector:
	var lines: PackedStringArray = PackedStringArray()

	func collect(annotation: SampleNote, target: Object) -> void:
		lines.append("annotation %s note=%s target=%s" % [_annotation_name(annotation), _format_note(annotation.note), _format_target(target)])

	func _annotation_name(annotation: SampleNote) -> String:
		var script := annotation.get_script() as GDScript
		if script == null:
			return "SampleNote"
		var global_name := String(script.get_global_name())
		if global_name.is_empty():
			return "SampleNote"
		return global_name

	func _format_note(note: Dictionary) -> String:
		var keys: Array = note.keys()
		keys.sort()
		var parts: PackedStringArray = PackedStringArray()
		for key in keys:
			parts.append("%s=%s" % [key, note[key]])
		return "{%s}" % ", ".join(parts)

	func _format_target(target: Object) -> String:
		if target is ScriptInfo:
			var script_info := target as ScriptInfo
			var path := ""
			if script_info.gdscript != null:
				path = script_info.gdscript.resource_path
			return "script %s" % path
		if target is VariableInfo:
			var variable_info := target as VariableInfo
			return "variable %s" % variable_info.name
		if target is FunctionInfo:
			var function_info := target as FunctionInfo
			return "function %s" % function_info.name
		if target is ParameterInfo:
			var parameter_info := target as ParameterInfo
			return "parameter %s/%s" % [parameter_info.function, parameter_info.name]
		return "unknown"
