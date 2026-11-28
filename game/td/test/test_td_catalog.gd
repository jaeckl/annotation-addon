extends GutTest


func test_tower_levels_and_upgrade_costs() -> void:
	var catalog := TdCatalog.new()
	var arrow := catalog.tower(&"arrow")
	assert_false(arrow.is_empty(), "arrow exists")
	assert_eq((arrow["damage"] as Array).size(), 3, "3 damage tiers")
	assert_eq((arrow["upgrade_cost"] as Array).size(), 2, "two upgrades to reach L3")
	assert_gt(int(arrow["build_cost"]), 0, "build costs gold")


func test_creep_bounties() -> void:
	var catalog := TdCatalog.new()
	assert_gt(int(catalog.creep(&"runner")["bounty"]), 0, "runner pays")
	assert_gt(int(catalog.creep(&"boss")["bounty"]), int(catalog.creep(&"swarm")["bounty"]), "boss pays more")
