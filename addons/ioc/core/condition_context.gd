class_name ConditionContext
extends RefCounted

## What a Condition can see. environment is the property environment.
## registry() is a copy of the products visible to this check. Changing the
## returned list or a copied definition does not change registration.
## A condition that reads the registry overrides depends_on_registry so the
## copy is taken after the other definitions exist.
## scene_root is the scene root being entered. A node condition overrides
## depends_on_scene so this is set. It is null during discovery.
var environment: PropertyEnvironment
var scene_root: Node
var _products: Array = []


func _init(property_environment: PropertyEnvironment, products: Array, root: Node = null) -> void:
	environment = property_environment
	scene_root = root
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


func has_node_type(type: GDScript) -> bool:
	if type == null or scene_root == null or not is_instance_valid(scene_root):
		return false
	return _tree_has(scene_root, type)


func _tree_has(node: Node, type: GDScript) -> bool:
	var script := node.get_script() as GDScript
	var current := script
	while current != null:
		if current == type:
			return true
		current = current.get_base_script()
	for child in node.get_children():
		# A nested scene root belongs to its own scene.
		if String(child.scene_file_path) != "":
			continue
		if _tree_has(child, type):
			return true
	return false


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
