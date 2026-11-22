@Pooled
@Component
class_name PoolBolt
extends Node2D

var wakes := 0
var binds := 0
@Inject var pools: InstancePools
@Inject var clock: PoolClock:
	set(value):
		clock = value
		binds += 1


func _ready() -> void:
	wakes += 1
