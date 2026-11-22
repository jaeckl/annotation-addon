class_name ConditionalOnComponent
extends Condition

## Matches when a registered product is this global class or a subclass of it.
## The check runs after definitions that do not depend on the registry exist.
## A product that itself depends on the registry does not count.
## Several conditions on one target all have to match.
var type_name: String = ""
const repeatable := true


func depends_on_registry() -> bool:
	return true


func matches(_environment: PropertyEnvironment) -> bool:
	var script := component_script(type_name, "@ConditionalOnComponent")
	if script == null:
		return false
	return registry_has(script)
