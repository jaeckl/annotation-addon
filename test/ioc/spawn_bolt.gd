@Scene("res://test/ioc/spawn_bolt.tscn")
@Component
class_name SpawnBolt
extends Node2D

var hits := 0
@Inject var clock: SpawnClock:
	set(value):
		clock = value
		hits += 1
