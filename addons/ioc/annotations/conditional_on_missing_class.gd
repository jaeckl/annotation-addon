class_name ConditionalOnMissingClass
extends Condition

## Matches when this native, extension, or global class name is absent.
## The name is text because a missing class cannot be written as a type.
## Several conditions on one target all have to match.
var type_name: String = ""
const repeatable := true


func matches(_context: ConditionContext) -> bool:
	var named := type_name.strip_edges()
	if named.is_empty():
		push_error("IOC: @ConditionalOnMissingClass needs a type_name.")
		return false
	return not type_present(named)
