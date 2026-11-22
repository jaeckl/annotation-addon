extends Node

## Scene consumer. Godot created this node. The container fills @Inject when
## the node enters the tree, before @onready and _ready. This script has no
## class_name and is not a @Component.
@Inject var clock: GameClock
@Qualifier("brute")
@Inject var bruiser: Enemy
@Rank(kind = "boss")
@Inject var boss: Enemy
@Offline
@Inject var stalker: Enemy
@onready var badge_text: String = $Badge.text
@onready var clock_ready: bool = clock != null and clock.started
