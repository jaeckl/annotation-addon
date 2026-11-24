@RunScope
@Component
class_name RunWallet
extends RefCounted

@Inject var log: RunLog
var gold := 100


@Ready
func boot() -> void:
	log.lines.append("ready:wallet")


@OnDestroy
func down() -> void:
	log.lines.append("down:wallet")
