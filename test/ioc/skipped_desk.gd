@Component
class_name SkippedDesk
extends RefCounted

var ran := 0


@Skipped
func ping() -> String:
	ran += 1
	return "pong"
