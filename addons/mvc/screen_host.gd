class_name ScreenHost
extends RefCounted

## Shows one view and hides the one that was open. A view stays instanced.
var current: Node = null


func show(view: Node) -> void:
	if view == null or not is_instance_valid(view):
		push_error("MVC: show needs a view.")
		return
	if not _can_show(view):
		push_error("MVC: %s cannot be shown." % view.name)
		return
	if current != null and current != view and is_instance_valid(current):
		_set_visible(current, false)
	current = view
	_set_visible(view, true)


func hide(view: Node) -> void:
	if view == null or not is_instance_valid(view):
		return
	if current == view:
		current = null
	_set_visible(view, false)


func _can_show(node: Node) -> bool:
	return node is CanvasItem or node is Node3D


func _set_visible(node: Node, shown: bool) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = shown
	elif node is Node3D:
		(node as Node3D).visible = shown
