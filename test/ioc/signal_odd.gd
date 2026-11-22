@Component
class_name SignalOdd
extends Node

signal rang


@SignalListener("rang")
func on_rang():
	return 4
