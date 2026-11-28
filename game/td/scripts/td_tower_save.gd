@Serialize
class_name TdTowerSave
extends RefCounted

## Persist shape for one placed tower. Live TdTower nodes stay @Transient on
## TdTowerField and are rebuilt in bind_world after load.

@Required
var kind: String = "arrow"
@Required
var level: int = 1
@Required
var cell: Vector2i = Vector2i.ZERO


static func from_tower(tower: TdTower) -> TdTowerSave:
	var row := TdTowerSave.new()
	if tower == null:
		return row
	row.kind = String(tower.kind)
	row.level = tower.level
	row.cell = tower.cell
	return row
