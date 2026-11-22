@Component
class_name InputGate
extends RefCounted

var ran := 0


@UnhandledInput(action="jump", pressed=true)
func on_jump(_event: InputEvent) -> bool:
	ran += 1
	return true
