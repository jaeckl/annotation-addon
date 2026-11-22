class_name ConditionalOnClass
extends Condition

## Matches when this native, extension, or global class name exists.
## The name is text because a missing class cannot be written as a type.
## Several conditions on one target all have to match.
var type_name: String = ""
const repeatable := true


func matches(_environment: PropertyEnvironment) -> bool:
	var named := type_name.strip_edges()
	if named.is_empty():
		push_error("IOC: @ConditionalOnClass needs a type_name.")
		return false
	return type_present(named)
