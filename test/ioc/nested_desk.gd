@Component
class_name NestedDesk
extends RefCounted

var ran := 0


@NestedMark
func ping() -> String:
	ran += 1
	return "pong"
