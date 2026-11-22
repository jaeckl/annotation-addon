extends Node

@Inject var clock: GameClock
@onready var clock_ready: bool = clock != null and clock.started
