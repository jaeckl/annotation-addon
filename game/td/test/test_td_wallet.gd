extends GutTest


func test_try_spend_and_credit() -> void:
	var wallet := TdWallet.new()
	wallet.gold = 50
	assert_true(wallet.try_spend(40), "can afford")
	assert_eq(wallet.gold, 10, "spent")
	assert_false(wallet.try_spend(40), "too expensive")
	assert_eq(wallet.gold, 10, "unchanged")
	wallet.credit(5)
	assert_eq(wallet.gold, 15, "credited")


func test_creep_died_listener_credits_bounty() -> void:
	var wallet := TdWallet.new()
	wallet.gold = 0
	var event := TdCreepDied.new()
	event.bounty = 7
	wallet.on_creep_died(event)
	assert_eq(wallet.gold, 7, "bounty applied")
