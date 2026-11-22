@Component
class_name InputWoven
extends RefCounted

var ran := 0


@Logged
@UnhandledInput
func on_input(_event: InputEvent) -> void:
	ran += 1
