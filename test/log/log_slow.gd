@Component
class_name LogSlow
extends RefCounted


@Timed
func always() -> int:
	return 1


@Timed(999999.0)
func fast() -> int:
	return 2
