class_name ParentDesk
extends RefCounted

var inner_count := 0


@Logged
func inner() -> String:
	inner_count += 1
	return "inner"
