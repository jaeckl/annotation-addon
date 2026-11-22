class_name ResourcePropertySourceParser
extends PropertySourceParser

## Reads a .tres whose script has @ConfigurationProperties. Each @export
## becomes prefix/field. The loaded resource is duplicated first, so the
## cached .tres stays unchanged. This source is loaded before the cfg files,
## which makes it the lowest layer.


func handles(path: String) -> bool:
	return path.get_extension().to_lower() == "tres"


func parse(path: String) -> PropertySource:
	var loaded := load(path)
	if loaded == null or not (loaded is Resource):
		push_error("IOC: cannot read property resource %s." % path)
		return null
	var copy := (loaded as Resource).duplicate()
	if copy == null:
		push_error("IOC: cannot duplicate property resource %s." % path)
		return null
	var script := copy.get_script() as GDScript
	if script == null:
		push_error("IOC: %s needs a GDScript resource." % path)
		return null
	var prefix := _prefix(script)
	if prefix.is_empty():
		push_error("IOC: %s needs @ConfigurationProperties." % path)
		return null
	var values := {}
	var seen := {}
	for property in script.get_script_property_list():
		var property_name := String(property.get("name", ""))
		if property_name.is_empty() or seen.has(property_name):
			continue
		var usage := int(property.get("usage", 0))
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		if (usage & PROPERTY_USAGE_EDITOR) == 0:
			continue
		seen[property_name] = true
		values["%s/%s" % [prefix, property_name]] = copy.get(property_name)
	var source := MapPropertySource.new()
	source.source_name = path
	source.fill(values)
	return source


func _prefix(script: GDScript) -> String:
	if not AnnotationUtils.has_annotation(script, ConfigurationProperties):
		return ""
	var bucket := {"prefix": ""}
	AnnotationUtils.for_each_annotation_initialized(ConfigurationProperties, script, _take_prefix.bind(bucket))
	return String(bucket["prefix"]).strip_edges().trim_suffix("/")


func _take_prefix(annotation: Object, target: Object, bucket: Dictionary) -> void:
	if target is ScriptInfo:
		bucket["prefix"] = String(annotation.get("prefix"))
