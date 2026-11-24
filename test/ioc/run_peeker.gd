@Component
class_name RunPeeker
extends RefCounted

@Inject var runs: Runs
@Inject var log: RunLog
var started := 0
var gold_at_end := -1
var end_again := false
var warm_up := false


func gold() -> int:
	var wallet := runs.resolve(RunWallet) as RunWallet
	return wallet.gold if wallet != null else -1


@EventListener
func on_started(_event: RunStarted) -> void:
	started += 1
	if warm_up:
		runs.resolve(RunTicker)


@EventListener
func on_ending(_event: RunEnding) -> void:
	gold_at_end = gold()
	if end_again:
		runs.end()


@OnDestroy
func down() -> void:
	log.lines.append("down:peeker")
