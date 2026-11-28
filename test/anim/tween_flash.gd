@Component
class_name TweenFlash
extends Node2D

var body_ran := 0


@TweenPlay(props = { "modulate:a": 0.0 }, duration = 0.05)
func flash() -> void:
	body_ran += 1
