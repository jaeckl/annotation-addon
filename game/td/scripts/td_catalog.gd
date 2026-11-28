@Component
@Eager
class_name TdCatalog
extends RefCounted

## Tower and creep stats. Levels 1..3; upgrade_cost[level] pays to reach level+1.


func tower(kind: StringName) -> Dictionary:
	match String(kind):
		"arrow":
			return {
				"label": "Arrow",
				"color": Color(0.2, 0.75, 0.85),
				"build_cost": 40,
				"upgrade_cost": [30, 50],
				"damage": [8, 12, 18],
				"range": [2.2, 2.5, 2.9],
				"cooldown": 0.45,
				"aoe": 0.0,
				"slow": 0.0,
			}
		"cannon":
			return {
				"label": "Cannon",
				"color": Color(0.95, 0.45, 0.2),
				"build_cost": 65,
				"upgrade_cost": [45, 70],
				"damage": [14, 22, 34],
				"range": [1.8, 2.0, 2.3],
				"cooldown": 0.9,
				"aoe": 1.1,
				"slow": 0.0,
			}
		"slow":
			return {
				"label": "Slow",
				"color": Color(0.65, 0.35, 0.9),
				"build_cost": 50,
				"upgrade_cost": [35, 55],
				"damage": [2, 3, 4],
				"range": [2.0, 2.3, 2.6],
				"cooldown": 0.35,
				"aoe": 0.0,
				"slow": 0.45,
			}
		_:
			return {}


func creep(kind: StringName) -> Dictionary:
	match String(kind):
		"runner":
			return {"hp": 30, "speed": 55.0, "bounty": 6, "radius": 10.0, "color": Color(0.9, 0.3, 0.3)}
		"tank":
			return {"hp": 120, "speed": 28.0, "bounty": 18, "radius": 16.0, "color": Color(0.35, 0.55, 0.35)}
		"swarm":
			return {"hp": 14, "speed": 70.0, "bounty": 3, "radius": 7.0, "color": Color(0.95, 0.8, 0.2)}
		"boss":
			return {"hp": 500, "speed": 22.0, "bounty": 80, "radius": 22.0, "color": Color(0.7, 0.1, 0.7)}
		_:
			return {}


func kinds() -> Array[StringName]:
	return [&"arrow", &"cannon", &"slow"]
