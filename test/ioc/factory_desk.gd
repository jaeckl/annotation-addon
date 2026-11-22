class_name FactoryDesk
extends RefCounted

var ran := 0


@Logged
func ping() -> String:
	ran += 1
	return "pong"
