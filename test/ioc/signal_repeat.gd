@Component
class_name SignalRepeat
extends Node

signal ping
signal pong

var seen: Array = []


@SignalListener("ping")
@SignalListener("pong")
func on_either() -> void:
	seen.append(seen.size())
