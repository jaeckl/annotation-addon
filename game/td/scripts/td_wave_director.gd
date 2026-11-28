@Persist
@RunScope
@Eager
@Component
class_name TdWaveDirector
extends RefCounted

## Spawns creeps from a fixed wave table. Cadence from TdSettings.

@Inject var catalog: TdCatalog
@Inject var settings: TdSettings
@Inject var pools: InstancePools
@Inject var events: EventPublisher

@Serialize var wave_index: int = 0
@Serialize var spawned_in_wave: int = 0
@Serialize var active: bool = false

var creeps: Array = []
var parent: Node2D
var _spawn_cd: float = 0.0
var _between_cd: float = 3.0
var _started := false

const WAVES: Array = [
	[{"kind": "runner", "count": 6}],
	[{"kind": "runner", "count": 8}, {"kind": "swarm", "count": 4}],
	[{"kind": "tank", "count": 3}, {"kind": "runner", "count": 6}],
	[{"kind": "swarm", "count": 12}],
	[{"kind": "tank", "count": 4}, {"kind": "swarm", "count": 8}],
	[{"kind": "runner", "count": 10}, {"kind": "tank", "count": 4}],
	[{"kind": "swarm", "count": 16}, {"kind": "runner", "count": 8}],
	[{"kind": "tank", "count": 6}, {"kind": "runner", "count": 10}],
	[{"kind": "boss", "count": 1}, {"kind": "runner", "count": 8}],
]


func bind_world(world: Node2D) -> void:
	parent = world
	if not _started:
		_between_cd = settings.wave_intro_seconds if settings != null else 2.5
		_started = true


func wave_count() -> int:
	return WAVES.size()


func current_display() -> int:
	return mini(wave_index + 1, WAVES.size())


@Process
func tick(delta: float) -> void:
	_prune()
	if parent == null or catalog == null or pools == null:
		return
	if wave_index >= WAVES.size():
		return
	if not active:
		_between_cd -= delta
		if _between_cd <= 0.0:
			active = true
			spawned_in_wave = 0
			_spawn_cd = 0.0
		return
	var plan: Array = WAVES[wave_index]
	var total := _plan_total(plan)
	if spawned_in_wave < total:
		_spawn_cd -= delta
		if _spawn_cd <= 0.0:
			_spawn_next(plan)
			_spawn_cd = settings.spawn_interval_seconds if settings != null else 0.55
		return
	if creeps.is_empty():
		_finish_wave()


func _spawn_next(plan: Array) -> void:
	var kind := _kind_at(plan, spawned_in_wave)
	var base := catalog.creep(kind)
	if base.is_empty():
		spawned_in_wave += 1
		return
	var creep := pools.borrow(TdCreep, parent) as TdCreep
	if creep == null:
		return
	var spec := base.duplicate()
	spec["kind"] = String(kind)
	creep.setup(spec, events, pools)
	creeps.append(creep)
	spawned_in_wave += 1


@Logged
func _finish_wave() -> void:
	active = false
	if events != null:
		var cleared := TdWaveCleared.new()
		cleared.wave = wave_index + 1
		events.publish(cleared)
	wave_index += 1
	if wave_index >= WAVES.size():
		if events != null:
			var over := TdRunOver.new()
			over.won = true
			events.publish(over)
		return
	_between_cd = settings.wave_gap_seconds if settings != null else 3.0


func _plan_total(plan: Array) -> int:
	var total := 0
	for entry in plan:
		total += int(entry.get("count", 0))
	return total


func _kind_at(plan: Array, index: int) -> StringName:
	var cursor := 0
	for entry in plan:
		var count := int(entry.get("count", 0))
		if index < cursor + count:
			return StringName(str(entry.get("kind", "runner")))
		cursor += count
	return &"runner"


func _prune() -> void:
	var i := 0
	while i < creeps.size():
		var creep := creeps[i] as TdCreep
		if creep == null or not is_instance_valid(creep) or not creep.alive:
			creeps.remove_at(i)
			continue
		i += 1


func advance_creeps(delta: float) -> void:
	for item in creeps:
		var creep := item as TdCreep
		if creep != null and creep.alive:
			creep.advance(delta)
