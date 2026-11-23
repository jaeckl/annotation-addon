@RunScope
@Component
class_name RunBody
extends Node

@Inject var wallet: RunWallet
var wallet_at_ready: RunWallet


func _ready() -> void:
	wallet_at_ready = wallet
