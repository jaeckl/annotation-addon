class_name ProjectSettingsPropertySource
extends PropertySource

## Reads ProjectSettings by the same section/key the cfg files use.
## Sits above the files. Engine settings are visible too, and the binder
## only asks for keys that match an exported field.


func _init() -> void:
	source_name = "project-settings"


func contains(key: String) -> bool:
	return ProjectSettings.has_setting(key)


func get_value(key: String) -> Variant:
	return ProjectSettings.get_setting(key)
