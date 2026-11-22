class_name OnTownMusic
extends Condition

## Custom condition. Reads the environment from the context.
func matches(context: ConditionContext) -> bool:
	if context == null or context.environment == null:
		return false
	if not context.environment.contains("audio/music"):
		return false
	return not str(context.environment.get_value("audio/music")).strip_edges().is_empty()
