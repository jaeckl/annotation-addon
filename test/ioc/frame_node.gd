@Component
class_name FrameNode
extends Node

var ran := 0


@Process
func tick(_delta: float) -> void:
	ran += 1


@PhysicsProcess
func phys(_delta: float) -> void:
	ran += 1
