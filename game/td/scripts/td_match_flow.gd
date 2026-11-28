@StateMachine(transitions = {
	0: [1, 2],
	1: [0, 2, 3, 4],
	2: [1, 0],
	3: [0],
	4: [0],
})
@RunScope
@Eager
@Component
class_name TdMatchFlow
extends FsmObject

## Match phases for one run.

enum Phase { MENU, PLAYING, PAUSED, WON, LOST }

@Inject var events: EventPublisher
var paused_tree := false


func _init() -> void:
	state = Phase.PLAYING


@Process
func drive(delta: float) -> void:
	tick(delta)


@OnEnter(Phase.PAUSED)
func enter_pause() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.paused = true
		paused_tree = true


@OnExit(Phase.PAUSED)
func leave_pause() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and paused_tree:
		tree.paused = false
		paused_tree = false


@OnEnter(Phase.WON)
func enter_won() -> void:
	_unpause()


@OnEnter(Phase.LOST)
func enter_lost() -> void:
	_unpause()


@EventListener
func on_run_over(event: TdRunOver) -> void:
	if event.won:
		try_goto(Phase.WON)
	else:
		try_goto(Phase.LOST)


func toggle_pause() -> void:
	if state == Phase.PLAYING:
		try_goto(Phase.PAUSED)
	elif state == Phase.PAUSED:
		try_goto(Phase.PLAYING)


func _unpause() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.paused:
		tree.paused = false
		paused_tree = false
