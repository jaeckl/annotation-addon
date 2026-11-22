@Component
class_name TimedDesk
extends RefCounted


@Timed
func ping() -> String:
	return "pong"
