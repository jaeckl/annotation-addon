class_name PropertyEnvironment
extends RefCounted

## Ordered property sources for the process. The first source that contains
## the key wins. add_first puts a source at index 0, so it beats sources
## already loaded. A missing key is contains == false. get_value is null
## then, which is also a stored null, so callers check contains.
var sources: Array = []


func add_first(source: PropertySource) -> void:
	sources.insert(0, source)


func add_last(source: PropertySource) -> void:
	sources.append(source)


func contains(key: String) -> bool:
	for source in sources:
		var origin := source as PropertySource
		if origin != null and origin.contains(key):
			return true
	return false


func get_value(key: String) -> Variant:
	for source in sources:
		var origin := source as PropertySource
		if origin != null and origin.contains(key):
			return origin.get_value(key)
	return null
