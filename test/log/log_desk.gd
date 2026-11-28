@Component
class_name LogDesk
extends RefCounted

var hits := 0


@Logged
func ping() -> String:
	hits += 1
	return "pong"


@Logged("warn")
func warn_ping() -> String:
	return "careful"
