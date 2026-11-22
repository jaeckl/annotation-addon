@tool
extends EditorPlugin

const SAMPLE_SCRIPT := "res://samples/sample_annotated.gd"


func _enter_tree() -> void:
	add_tool_menu_item("Print annotation reflection", _print_sample)
	call_deferred("_print_sample")


func _exit_tree() -> void:
	remove_tool_menu_item("Print annotation reflection")


func _print_sample() -> void:
	var script := load(SAMPLE_SCRIPT) as GDScript
	if script == null:
		push_error("Annotation sample script is missing.")
		return
	print(AnnotationReflect.describe(script))
