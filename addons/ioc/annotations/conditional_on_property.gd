class_name ConditionalOnProperty
extends Condition

## Reads one environment key. It does not resolve a settings object.
## An empty having_value matches any present value except false.
## match_if_missing matches only when the key is absent. A present value
## is still compared.
var key: String = ""
var having_value: String = ""
var match_if_missing: bool = false
const repeatable := true


func matches(context: ConditionContext) -> bool:
	var property_environment := context.environment if context != null else null
	var property_key := key.strip_edges()
	if property_key.is_empty():
		push_error("IOC: @ConditionalOnProperty needs a key.")
		return false
	if property_environment == null or not property_environment.contains(property_key):
		return match_if_missing
	var value: Variant = property_environment.get_value(property_key)
	if having_value.is_empty():
		return not _is_false(value)
	return _same(value, having_value)


func _is_false(value: Variant) -> bool:
	if typeof(value) == TYPE_BOOL:
		return value == false
	if typeof(value) == TYPE_STRING:
		return String(value).strip_edges().to_lower() == "false"
	return false


func _same(value: Variant, expected: String) -> bool:
	var actual := _text(value)
	var wanted := expected.strip_edges()
	if _is_bool_word(actual) and _is_bool_word(wanted):
		return actual.to_lower() == wanted.to_lower()
	return actual == wanted


func _text(value: Variant) -> String:
	if typeof(value) == TYPE_BOOL:
		return "true" if value else "false"
	return str(value)


func _is_bool_word(text: String) -> bool:
	var lowered := text.strip_edges().to_lower()
	return lowered == "true" or lowered == "false"
