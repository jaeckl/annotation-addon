class_name ConfigFilePropertySourceParser
extends PropertySourceParser

## Reads a ConfigFile. Each entry becomes section/key, the same shape as
## ProjectSettings. The section is required. A key is not promoted to the
## root.


func handles(path: String) -> bool:
	return path.get_extension().to_lower() == "cfg"


func parse(path: String) -> PropertySource:
	var file := ConfigFile.new()
	var error := file.load(path)
	if error != OK:
		push_error("IOC: cannot read property file %s (%s)." % [path, error_string(error)])
		return null
	var values := {}
	for section in file.get_sections():
		for key in file.get_section_keys(section):
			values["%s/%s" % [String(section), String(key)]] = file.get_value(section, key)
	var source := MapPropertySource.new()
	source.source_name = path
	source.fill(values)
	return source
