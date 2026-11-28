@Pooled(64)
@Component
class_name TdCreep
extends Node2D

## Pooled enemy. Configure after borrow, then release when dead or leaked.

@Inject var settings: TdSettings

var kind: StringName = &"runner"
var hp: float = 1.0
var max_hp: float = 1.0
var speed: float = 40.0
var base_speed: float = 40.0
var bounty: int = 1
var radius: float = 10.0
var tint: Color = Color.WHITE
var waypoint: int = 0
var alive := false
var slow_timer: float = 0.0

var _events: EventPublisher
var _pools: InstancePools


func setup(spec: Dictionary, events: EventPublisher, pools: InstancePools) -> void:
	kind = StringName(str(spec.get("kind", "runner")))
	max_hp = float(spec.get("hp", 10))
	hp = max_hp
	base_speed = float(spec.get("speed", 40))
	speed = base_speed
	bounty = int(spec.get("bounty", 1))
	radius = float(spec.get("radius", 10))
	tint = spec.get("color", Color.WHITE)
	waypoint = 0
	alive = true
	slow_timer = 0.0
	_events = events
	_pools = pools
	position = TdPath.waypoint_world(0, _cell())
	modulate = Color(1, 1, 1, 1)
	scale = Vector2.ONE
	show()
	queue_redraw()


func apply_slow(factor: float, duration: float) -> void:
	speed = base_speed * clampf(1.0 - factor, 0.25, 1.0)
	slow_timer = maxf(slow_timer, duration)


func hurt(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		_die()


@Timed(8.0)
func advance(delta: float) -> void:
	if not alive:
		return
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			speed = base_speed
	var target := TdPath.waypoint_world(waypoint, _cell())
	var offset := target - position
	var step := speed * delta
	if offset.length() <= step:
		position = target
		waypoint += 1
		if waypoint >= TdPath.CELLS.size():
			_leak()
			return
	else:
		position += offset.normalized() * step
	queue_redraw()


func _die() -> void:
	if not alive:
		return
	alive = false
	if _events != null:
		var ev := TdCreepDied.new()
		ev.bounty = bounty
		ev.kind = kind
		_events.publish(ev, self)
	_recycle()


func _leak() -> void:
	if not alive:
		return
	alive = false
	if _events != null:
		var hit := TdBaseHit.new()
		hit.damage = 1
		_events.publish(hit, self)
	_recycle()


func _recycle() -> void:
	if _pools != null:
		_pools.release(self)


@OnRelease
func park() -> void:
	alive = false
	hide()


func _cell() -> float:
	return settings.cell_size_f() if settings != null else 40.0


func _draw() -> void:
	if not alive and not visible:
		return
	draw_circle(Vector2.ZERO, radius, tint)
	if max_hp > 0.0:
		var w := radius * 2.0
		var ratio := clampf(hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(Vector2(-radius, -radius - 6.0), Vector2(w, 3.0)), Color(0.1, 0.1, 0.1))
		draw_rect(Rect2(Vector2(-radius, -radius - 6.0), Vector2(w * ratio, 3.0)), Color(0.2, 0.9, 0.3))
