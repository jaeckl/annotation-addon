@Lazy
@Component
class_name FrameAwait
extends RefCounted

## Lazy so default_init "eager" does not arm this invalid tick on every start.
signal resume
var started := 0


@Process
func tick(_delta: float) -> void:
	started += 1
	await resume
