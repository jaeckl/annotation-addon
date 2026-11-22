@UnhandledInput
@Component
class_name InputBadShape
extends RefCounted

@UnhandledInput var label: String = ""


@UnhandledInput
func no_args() -> void:
	pass


@UnhandledInput
func two(_event: InputEvent, _extra: int) -> void:
	pass


@UnhandledInput
static func stat(_event: InputEvent) -> void:
	pass


@UnhandledInput
func untyped(_event) -> void:
	pass


@UnhandledInput(action="no_such_ioc_action")
func missing(_event: InputEvent) -> void:
	pass


@UnhandledInput(action="jump", pressed=true, released=true)
func both(_event: InputEvent) -> void:
	pass


@UnhandledInput(pressed=true)
func bare_pressed(_event: InputEvent) -> void:
	pass
