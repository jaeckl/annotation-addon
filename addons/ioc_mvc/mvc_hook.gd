@Component
class_name MvcHook
extends ContainerHook

## Fills @Bind from the view and weaves @Property before the product is ready.


func weave(script: GDScript) -> Variant:
	var parts := PropertyWeaver.prepare(script)
	if parts.is_empty():
		return null
	var problem := String(parts.get("error", ""))
	if not problem.is_empty():
		push_error(problem)
		return null
	return parts


func before_ready(instance: Object) -> void:
	if instance == null:
		return
	var script := instance.get_script() as GDScript
	if _marked(script, View):
		_check_view(instance, script)
		_conceal(instance)
	if _marked(script, Model) and not _marked(script, Component):
		push_error("MVC: %s is @Model without @Component." % _type_name(script))
	if _marked(script, Controller):
		_arm_controller(instance, script)


func _check_view(instance: Object, script: GDScript) -> void:
	var label := _type_name(script)
	if not (instance is Node):
		push_error("MVC: %s is @View and is not a Node." % label)
		return
	if not _marked(script, Scene):
		push_error("MVC: %s is @View without @Scene." % label)


func _arm_controller(instance: Object, script: GDScript) -> void:
	var label := _type_name(script)
	if not _marked(script, Component):
		push_error("MVC: %s is @Controller without @Component." % label)
	if instance is Node:
		push_error("MVC: %s is @Controller on a Node." % label)
		return
	var views := _views(instance)
	if views.size() != 1:
		if views.is_empty():
			push_error("MVC: %s has no view." % label)
		else:
			push_error("MVC: %s injects more than one view." % label)
		return
	_bind_fields(instance, script, views[0] as Node, label)
	_conceal(views[0])


func _views(instance: Object) -> Array:
	var found: Array = []
	for property in instance.get_property_list():
		if (int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var value: Variant = instance.get(StringName(String(property.get("name", ""))))
		if not (value is Node) or not is_instance_valid(value):
			continue
		if _marked((value as Object).get_script() as GDScript, View):
			found.append(value)
	return found


func _bind_fields(instance: Object, script: GDScript, view: Node, label: String) -> void:
	var current := script
	while current != null:
		AnnotationUtils.for_each_annotation_initialized(Bind, current, _take_bind.bind(instance, view, label, current))
		current = current.get_base_script()


func _take_bind(annotation: Object, target: Object, instance: Object, view: Node, label: String, script: GDScript) -> void:
	if not (target is VariableInfo):
		push_error("MVC: @Bind on %s belongs on a field." % _type_name(script))
		return
	var info := target as VariableInfo
	if info.is_static:
		push_error("MVC: %s.%s is static and cannot be bound." % [label, info.name])
		return
	var path := NodePath()
	if annotation is Bind:
		path = (annotation as Bind).path
	if path.is_empty():
		path = NodePath("%%%s" % String(info.name))
	if _leaves(path):
		push_error("MVC: %s.%s leaves the view." % [label, info.name])
		return
	var node := view.get_node_or_null(path)
	if node == null or (node != view and not view.is_ancestor_of(node)):
		push_error("MVC: %s.%s is missing." % [label, info.name])
		return
	instance.set(StringName(String(info.name)), node)


func _leaves(path: NodePath) -> bool:
	if path.is_absolute():
		return true
	for index in path.get_name_count():
		if String(path.get_name(index)) == "..":
			return true
	return false


func _conceal(instance: Object) -> void:
	if instance is CanvasItem:
		(instance as CanvasItem).visible = false
	elif instance is Node3D:
		(instance as Node3D).visible = false


func _marked(script: GDScript, annotation: GDScript) -> bool:
	var current := script
	while current != null:
		if AnnotationUtils.has_annotation(current, annotation):
			return true
		current = current.get_base_script()
	return false


func _type_name(script: GDScript) -> String:
	var current := script
	while current != null:
		var global_name := current.get_global_name()
		if global_name != &"":
			return String(global_name)
		current = current.get_base_script()
	if script == null:
		return "?"
	return script.resource_path.get_file().get_basename()
