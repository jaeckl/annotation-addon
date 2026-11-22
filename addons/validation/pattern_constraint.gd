class_name Pattern
extends Constraint

## Matches when the whole string matches regexp. Null matches, so NotNull
## stays a separate constraint. A substring match does not pass.
var regexp: String = ""
const repeatable := true


func is_valid(candidate: Variant) -> bool:
	if candidate == null:
		return true
	if not (candidate is String):
		return false
	var expression := _expression()
	if expression == null:
		return false
	var found := expression.search(String(candidate))
	if found == null:
		return false
	return found.get_start() == 0 and found.get_end() == String(candidate).length()


func violation_message(candidate: Variant) -> String:
	if candidate != null and not (candidate is String):
		return "must be a string"
	if regexp.strip_edges().is_empty():
		return "needs a regexp"
	return "must match %s" % regexp


func _expression() -> RegEx:
	var source := regexp.strip_edges()
	if source.is_empty():
		push_error("Validation: @Pattern needs a regexp.")
		return null
	var expression := RegEx.new()
	if expression.compile(source) != OK:
		push_error("Validation: @Pattern regexp %s did not compile." % source)
		return null
	return expression
