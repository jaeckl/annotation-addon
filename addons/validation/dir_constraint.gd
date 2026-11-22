class_name Dir
extends Constraint

## Matches a res:// directory. A trailing slash is ignored, except on
## res:// itself. Null matches, so NotNull stays a separate constraint.
const repeatable := true


func is_valid(candidate: Variant) -> bool:
	var path := _path(candidate)
	if candidate == null:
		return true
	if path.is_empty():
		return false
	return DirAccess.dir_exists_absolute(path)


func violation_message(candidate: Variant) -> String:
	if candidate == null or _path(candidate).is_empty():
		return "must be a res:// directory"
	return "must be an existing res:// directory"


func _path(candidate: Variant) -> String:
	if not (candidate is String):
		return ""
	var path := String(candidate).strip_edges()
	if not path.begins_with("res://"):
		return ""
	if path.ends_with("/") and path != "res://":
		path = path.trim_suffix("/")
	return path
