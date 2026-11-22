class_name ConditionContext
extends RefCounted

## What a Condition can see. environment is the property environment.
## registry() is a copy of the products visible to this check. Changing the
## returned list or a copied definition does not change registration.
## A condition that reads the registry overrides depends_on_registry so the
## copy is taken after the other definitions exist.
var environment: PropertyEnvironment
var _products: Array = []


func _init(property_environment: PropertyEnvironment, products: Array) -> void:
	environment = property_environment
	for item in products:
		var definition := item as ComponentDefinition
		if definition == null:
			continue
		var copy := ComponentDefinition.new()
		copy.type = definition.type
		copy.qualifiers = definition.qualifiers.duplicate()
		copy.label = definition.label
		copy.owner_script = definition.owner_script
		copy.factory = definition.factory
		copy.method = definition.method
		_products.append(copy)


func registry() -> Array:
	return _products.duplicate()


func has_type(type: GDScript) -> bool:
	if type == null:
		return false
	for item in _products:
		var definition := item as ComponentDefinition
		if definition == null:
			continue
		var current := definition.type
		while current != null:
			if current == type:
				return true
			current = current.get_base_script()
	return false
