class_name ConditionalOnMissingComponent
extends Condition

## Matches when no registered product is this global class or a subclass of it.
## The candidate does not count itself. Another product that also depends on
## the registry does not count either. Several conditions on one target all
## have to match.
var type_name: String = ""
const repeatable := true


func depends_on_registry() -> bool:
	return true


func matches(context: ConditionContext) -> bool:
	var script := component_script(type_name, "@ConditionalOnMissingComponent")
	if script == null or context == null:
		return false
	return not context.has_type(script)
