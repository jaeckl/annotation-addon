class_name CandidateSelector
extends RefCounted

## Default selection policy. Keeps products whose type is the requested class
## or a subclass of it, then applies the qualifier matcher.
var _matcher: QualifierMatcher


func _init(matcher: QualifierMatcher) -> void:
	_matcher = matcher


func select(definitions: Array, type: GDScript, qualifiers: Array) -> Array:
	var found: Array = []
	for definition in definitions:
		var product := definition as ComponentDefinition
		if product == null or product.type == null:
			continue
		if _assignable(product.type, type) and _matcher.matches(product.qualifiers, qualifiers):
			found.append(product)
	return found


func _assignable(product: GDScript, requested: GDScript) -> bool:
	var current := product
	while current != null:
		if current == requested:
			return true
		current = current.get_base_script()
	return false
