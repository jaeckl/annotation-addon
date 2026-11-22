class_name ConditionalOnNode
extends Condition

## Matches when the entering scene root, or a descendant that belongs to that
## scene, uses this global class or a subclass of it. The check waits until
## that root enters. Several conditions on one target all have to match.
var type_name: String = ""
const repeatable := true


func depends_on_scene() -> bool:
	return true


func matches(context: ConditionContext) -> bool:
	var script := _node_script("@ConditionalOnNode")
	if script == null or context == null or context.scene_root == null:
		return false
	return context.has_node_type(script)


func _node_script(label: String) -> GDScript:
	var script := component_script(type_name, label)
	if script == null:
		return null
	var base := script.get_instance_base_type()
	if base != "Node" and not ClassDB.is_parent_class(base, "Node"):
		push_error("IOC: %s type %s is not a Node." % [label, type_name.strip_edges()])
		return null
	return script
