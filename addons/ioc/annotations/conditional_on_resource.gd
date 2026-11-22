class_name ConditionalOnResource
extends Condition

## Matches when this res:// file or directory exists. A missing addon path
## skips the definition. The path must start with res://. Several conditions
## on one target all have to match.
var path: String = ""
const repeatable := true


func matches(_context: ConditionContext) -> bool:
	var resource_path := path.strip_edges()
	if resource_path.is_empty():
		push_error("IOC: @ConditionalOnResource needs a path.")
		return false
	if not resource_path.begins_with("res://"):
		push_error("IOC: @ConditionalOnResource path %s must start with res://." % resource_path)
		return false
	if resource_path.ends_with("/") and resource_path != "res://":
		resource_path = resource_path.trim_suffix("/")
	return FileAccess.file_exists(resource_path) or DirAccess.dir_exists_absolute(resource_path)
