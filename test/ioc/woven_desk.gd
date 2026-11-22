@Component
@Qualifier("woven")
class_name WovenDesk
extends DeskBase

var plain_ran := 0


@Logged
func ping() -> String:
	return "pong"


@Logged
func add(amount: int = 2) -> int:
	return amount


func plain() -> String:
	plain_ran += 1
	return "plain"
