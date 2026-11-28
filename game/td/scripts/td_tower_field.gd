@Persist
@RunScope
@Eager
@Component
class_name TdTowerField
extends RefCounted

## Owns placed towers and projectiles. Persist stores TdTowerSave rows; live
## TdTower nodes are packed on write and rebuilt when the battle world binds.

@Inject var catalog: TdCatalog
@Inject var settings: TdSettings
@Inject var wallet: TdWallet
@Inject var pools: InstancePools

@Serialize
@Required
var towers: Array = []

@Transient var live: Array = []
@Transient var shots: Array = []
@Transient var selected: TdTower = null
@Transient var build_kind: StringName = &"arrow"
@Transient var parent: Node2D
@Transient var _restored := false


func bind_world(world: Node2D) -> void:
	parent = world
	if not _restored:
		_restore_from_save()
		_restored = true


func select_build(kind: StringName) -> void:
	build_kind = kind
	if selected != null:
		selected.selected = false
		selected.queue_redraw()
		selected = null


@OncePer("frame")
func try_build_at(world_pos: Vector2) -> bool:
	if parent == null or catalog == null or wallet == null or pools == null or settings == null:
		return false
	var cell := TdPath.world_to_cell(world_pos, settings.cell_size_f())
	if not TdPath.is_buildable(cell, settings.grid_width, settings.grid_height):
		return false
	if _occupied(cell):
		return false
	var spec := catalog.tower(build_kind)
	if spec.is_empty():
		return false
	var cost := int(spec.get("build_cost", 0))
	if not wallet.try_spend(cost):
		return false
	var tower := pools.borrow(TdTower, parent) as TdTower
	if tower == null:
		wallet.credit(cost)
		return false
	tower.setup(build_kind, 1, cell, spec, self)
	live.append(tower)
	return true


func try_select_or_upgrade(world_pos: Vector2) -> void:
	var tower := _at_world(world_pos)
	if tower == null:
		if selected != null:
			selected.selected = false
			selected.queue_redraw()
			selected = null
		return
	if selected == tower:
		_upgrade(tower)
		return
	if selected != null:
		selected.selected = false
		selected.queue_redraw()
	selected = tower
	selected.selected = true
	selected.queue_redraw()


func upgrade_selected() -> bool:
	if selected == null:
		return false
	return _upgrade(selected)


func _upgrade(tower: TdTower) -> bool:
	if wallet == null:
		return false
	var cost := tower.upgrade_cost()
	if cost < 0:
		return false
	if not wallet.try_spend(cost):
		return false
	if not tower.try_upgrade():
		wallet.credit(cost)
		return false
	return true


func tick(delta: float, creeps: Array) -> void:
	for item in live:
		var tower := item as TdTower
		if tower != null and is_instance_valid(tower):
			tower.advance(delta, creeps)
	var i := 0
	while i < shots.size():
		var shot := shots[i] as TdProjectile
		if shot == null or not is_instance_valid(shot) or not shot.live:
			shots.remove_at(i)
			continue
		shot.advance(delta)
		i += 1


func spawn_shot(tower: TdTower, target: TdCreep) -> void:
	if parent == null or pools == null or tower == null:
		return
	var shot := pools.borrow(TdProjectile, parent) as TdProjectile
	if shot == null:
		return
	shot.setup(
		tower.position,
		target,
		tower.damage(),
		float(tower.spec.get("aoe", 0.0)),
		float(tower.spec.get("slow", 0.0)),
		tower.spec.get("color", Color.WHITE),
		self,
		pools
	)
	shots.append(shot)


func apply_hit(primary: TdCreep, damage: float, aoe_px: float, slow: float) -> void:
	if primary != null and primary.alive:
		primary.hurt(damage)
		if slow > 0.0:
			primary.apply_slow(slow, 1.2)
	if aoe_px <= 0.0 or parent == null:
		return
	for child in parent.get_children():
		var creep := child as TdCreep
		if creep == null or creep == primary or not creep.alive:
			continue
		if primary != null and creep.position.distance_to(primary.position) <= aoe_px:
			creep.hurt(damage * 0.6)


@OnBeforeSerialization
func pack_towers() -> void:
	towers = []
	for item in live:
		var tower := item as TdTower
		if tower == null or not is_instance_valid(tower):
			continue
		towers.append(TdTowerSave.from_tower(tower))


@OnAfterDeserialization
func note_loaded() -> void:
	# Live nodes need the battle parent; bind_world spawns from `towers`.
	_restored = false
	live = []


func _restore_from_save() -> void:
	if parent == null or pools == null or catalog == null or settings == null:
		return
	live = []
	for item in towers:
		var row := item as TdTowerSave
		if row == null:
			continue
		var kind := StringName(row.kind)
		var spec := catalog.tower(kind)
		if spec.is_empty():
			continue
		var tower := pools.borrow(TdTower, parent) as TdTower
		if tower == null:
			continue
		tower.setup(kind, row.level, row.cell, spec, self)
		live.append(tower)


func _occupied(cell: Vector2i) -> bool:
	for item in live:
		var tower := item as TdTower
		if tower != null and tower.cell == cell:
			return true
	return false


func _at_world(pos: Vector2) -> TdTower:
	var hit := settings.select_hit_radius if settings != null else 18.0
	for item in live:
		var tower := item as TdTower
		if tower == null:
			continue
		if tower.position.distance_to(pos) <= hit:
			return tower
	return null
