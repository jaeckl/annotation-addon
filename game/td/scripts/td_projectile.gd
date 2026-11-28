@Pooled(96)
@Component
class_name TdProjectile
extends Node2D

## Flies toward a creep and applies damage (and optional AoE / slow).

@Inject var settings: TdSettings

var damage: float = 1.0
var aoe: float = 0.0
var slow: float = 0.0
var target: TdCreep
var live := false
var tint: Color = Color.WHITE

var _field: TdTowerField
var _pools: InstancePools


func setup(
	from: Vector2,
	to_creep: TdCreep,
	dmg: float,
	aoe_cells: float,
	slow_factor: float,
	color: Color,
	field: TdTowerField,
	pools: InstancePools
) -> void:
	position = from
	target = to_creep
	damage = dmg
	aoe = aoe_cells
	slow = slow_factor
	tint = color
	_field = field
	_pools = pools
	live = true
	show()
	queue_redraw()


func advance(delta: float) -> void:
	if not live:
		return
	if target == null or not is_instance_valid(target) or not target.alive:
		_recycle()
		return
	var speed := settings.projectile_speed if settings != null else 220.0
	var offset := target.position - position
	var step := speed * delta
	if offset.length() <= step + target.radius:
		_impact()
		return
	position += offset.normalized() * step
	queue_redraw()


func _impact() -> void:
	if _field != null:
		var size := settings.cell_size_f() if settings != null else 40.0
		_field.apply_hit(target, damage, aoe * size, slow)
	_recycle()


func _recycle() -> void:
	live = false
	if _pools != null:
		_pools.release(self)


@OnRelease
func park() -> void:
	live = false
	target = null
	hide()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, tint)
