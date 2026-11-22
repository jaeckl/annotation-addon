class_name File
extends Constraint

## Matches a res:// file. extension limits the suffix, with or without a
## dot. A missing file does not match. Null matches, so NotNull stays a
## separate constraint.
var extension: String = ""
const repeatable := true


func is_valid(candidate: Variant) -> bool:
	if candidate == null:
		return true
	var path := _path(candidate)
	if path.is_empty():
		return false
	var suffix := extension.strip_edges().trim_prefix(".").to_lower()
	if not suffix.is_empty() and path.get_extension().to_lower() != suffix:
		return false
	return FileAccess.file_exists(path)


func violation_message(candidate: Variant) -> String:
	var path := _path(candidate)
	if path.is_empty():
		return "must be a res:// file"
	var suffix := extension.strip_edges().trim_prefix(".")
	if not suffix.is_empty():
		return "must be an existing res:// .%s file" % suffix
	return "must be an existing res:// file"


func _path(candidate: Variant) -> String:
	if not (candidate is String):
		return ""
	var path := String(candidate).strip_edges()
	if not path.begins_with("res://"):
		return ""
	return path
