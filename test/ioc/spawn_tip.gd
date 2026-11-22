class_name SpawnTip
extends Node

var hits := 0
@Inject var clock: SpawnClock:
	set(value):
		clock = value
		hits += 1
