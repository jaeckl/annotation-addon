@RunScope
@Component
class_name RunBoard
extends RefCounted

@Inject var wallet: RunWallet
@Inject var log: RunLog


@Ready
func boot() -> void:
	log.lines.append("ready:board")


@OnDestroy
func down() -> void:
	log.lines.append("down:board")
