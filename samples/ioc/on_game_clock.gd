class_name OnGameClock
extends Condition

## Custom condition. Reads the copied product list from the context.
func depends_on_registry() -> bool:
	return true


func matches(context: ConditionContext) -> bool:
	if context == null:
		return false
	for item in context.registry():
		var definition := item as ComponentDefinition
		if definition != null and definition.label == "GameClock":
			return true
	return false
