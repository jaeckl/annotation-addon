@Component
class_name ScheduleClock
extends RefCounted

var ms := 0
var seconds := 0
var frames := 0
var physics := 0
var both := 0


@Scheduled("500ms")
func on_ms() -> void:
	ms += 1


@Scheduled("1s")
func on_seconds() -> void:
	seconds += 1


@Scheduled("3f")
func on_frames() -> void:
	frames += 1


@Scheduled("2pf")
func on_physics() -> void:
	physics += 1


@Scheduled("1f")
@Scheduled("2f")
func on_both() -> void:
	both += 1
