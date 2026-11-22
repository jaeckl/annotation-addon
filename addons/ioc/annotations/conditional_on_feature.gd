class_name ConditionalOnFeature
extends Condition

## Matches when OS.has_feature has this tag. editor, debug, template,
## dedicated_server, mobile, web, and a custom export tag all use it.
## Several conditions on one target all have to match.
var feature: String = ""
const repeatable := true


func matches(_environment: PropertyEnvironment) -> bool:
	var tag := feature.strip_edges()
	if tag.is_empty():
		push_error("IOC: @ConditionalOnFeature needs a feature.")
		return false
	return OS.has_feature(tag)
