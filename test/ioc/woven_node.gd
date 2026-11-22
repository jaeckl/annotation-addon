@Component
class_name WovenNode
extends Node

var hits := 0
var held: AdviceNote


@Inject var note: AdviceNote:
	set(value):
		hits += 1
		held = value


@Logged
func ping() -> String:
	return "node"
