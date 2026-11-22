class_name OnDefaultSpare
extends Condition

## Custom condition. DefaultSpare is itself deferred, so the snapshot omits it.
func depends_on_registry() -> bool:
	return true


func matches(context: ConditionContext) -> bool:
	if context == null:
		return false
	for item in context.registry():
		var definition := item as ComponentDefinition
		if definition != null and definition.label == "DefaultSpare":
			return true
	return false
