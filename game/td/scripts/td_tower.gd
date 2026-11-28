@Pooled(32)
@Component
class_name TdTower
extends Node2D

## Placed tower. kind + level set on borrow; fire uses per-instance cooldown.

var kind: StringName = &"arrow"
var level: int = 1
var cell: Vector2i = Vector2i.ZERO
var cell_size: float = 40.0
var selected := false
var _cooldown_left: float = 0.0
var spec: Dictionary = {}
var _field: TdTowerField


func setup(k: StringName, lvl: int, at: Vector2i, tower_spec: Dictionary, size: float, field: TdTowerField) -> void:
	kind = k
	level = clampi(lvl, 1, 3)
	cell = at
	spec = tower_spec
	cell_size = size
	_field = field
	_cooldown_left = 0.0
	selected = false
	position = TdPath.cell_to_world(cell, cell_size)
	scale = Vector2.ONE * (0.85 + 0.1 * float(level))
	modulate = Color(1, 1, 1, 1)
	show()
	queue_redraw()


func range_px() -> float:
	var ranges: Array = spec.get("range", [2.0])
	var idx := mini(level - 1, ranges.size() - 1)
	return float(ranges[idx]) * cell_size


func damage() -> float:
	var values: Array = spec.get("damage", [1.0])
	var idx := mini(level - 1, values.size() - 1)
	return float(values[idx])


func upgrade_cost() -> int:
	if level >= 3:
		return -1
	var costs: Array = spec.get("upgrade_cost", [])
	if level - 1 >= costs.size():
		return -1
	return int(costs[level - 1])


func try_upgrade() -> bool:
	if level >= 3:
		return false
	level += 1
	scale = Vector2.ONE * (0.85 + 0.1 * float(level))
	queue_redraw()
	return true


func advance(delta: float, creeps: Array) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
	var target := _acquire(creeps)
	if target == null:
		return
	if _cooldown_left > 0.0:
		return
	_fire(target)
	_cooldown_left = float(spec.get("cooldown", 0.5))


@Logged
func _fire(target: TdCreep) -> void:
	if _field != null:
		_field.spawn_shot(self, target)


func _acquire(creeps: Array) -> TdCreep:
	var best: TdCreep = null
	var best_d := INF
	var reach := range_px()
	for item in creeps:
		var creep := item as TdCreep
		if creep == null or not creep.alive:
			continue
		var d := position.distance_to(creep.position)
		if d <= reach and d < best_d:
			best = creep
			best_d = d
	return best


@OnRelease
func park() -> void:
	selected = false
	_field = null
	hide()


func _draw() -> void:
	var color: Color = spec.get("color", Color.WHITE)
	var r := 14.0 + float(level) * 2.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -r),
		Vector2(r * 0.9, r * 0.7),
		Vector2(-r * 0.9, r * 0.7),
	]), color)
	if selected:
		draw_arc(Vector2.ZERO, range_px(), 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
