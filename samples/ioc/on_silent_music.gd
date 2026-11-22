class_name OnSilentMusic
extends Condition

## Custom condition. The demo track is never silent, so this stays closed.
func matches(context: ConditionContext) -> bool:
	if context == null or context.environment == null:
		return false
	return str(context.environment.get_value("audio/music")) == "silent"
