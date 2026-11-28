class_name CandidateSelector
extends RefCounted

## Default selection policy. Keeps products whose type is the requested class
## or a subclass of it, then applies the qualifier matcher. prefer_primary
## narrows several matches to the @Primary ones for a single resolve.
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


## When several candidates remain for one resolve, keep only the @Primary
## ones if any exist. An empty primary set leaves the list unchanged, so the
## call still fails as ambiguous. Collections skip this step.
func prefer_primary(candidates: Array) -> Array:
	if candidates.size() <= 1:
		return candidates
	var primaries: Array = []
	for definition in candidates:
		var product := definition as ComponentDefinition
		if product != null and product.primary:
			primaries.append(product)
	if primaries.is_empty():
		return candidates
	return primaries


func _assignable(product: GDScript, requested: GDScript) -> bool:
	var current := product
	while current != null:
		if current == requested:
			return true
		current = current.get_base_script()
	return false
