@Component
class_name ChildDesk
extends ParentDesk

var outer_count := 0


@Logged
func outer() -> String:
	outer_count += 1
	inner()
	return "outer"


func jump() -> String:
	return super.inner()
