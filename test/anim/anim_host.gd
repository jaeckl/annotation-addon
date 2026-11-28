@Component
class_name AnimHost
extends Node

var finished_hits := 0
var started_hits := 0


func _ready() -> void:
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	var animation := Animation.new()
	animation.length = 0.05
	var library := AnimationLibrary.new()
	library.add_animation("wave", animation)
	player.add_animation_library("", library)
	add_child(player)


@OnAnim(player = ^"AnimationPlayer", on_finished = true, animation = "wave")
func on_wave_done() -> void:
	finished_hits += 1


@OnAnim(player = ^"AnimationPlayer", on_started = true, animation = "wave")
func on_wave_start() -> void:
	started_hits += 1
