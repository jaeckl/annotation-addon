class_name TdPath
extends RefCounted

## Grid path for the demo map. Size and cell scale come from TdSettings.

## Waypoints in cell coordinates (center of each path cell).
const CELLS: Array[Vector2i] = [
	Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5),
	Vector2i(4, 5), Vector2i(4, 4), Vector2i(4, 3), Vector2i(4, 2),
	Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2),
	Vector2i(9, 2), Vector2i(9, 3), Vector2i(9, 4), Vector2i(9, 5),
	Vector2i(9, 6), Vector2i(9, 7), Vector2i(9, 8), Vector2i(10, 8),
	Vector2i(11, 8), Vector2i(12, 8), Vector2i(13, 8), Vector2i(14, 8),
	Vector2i(15, 8),
]


static func is_path(cell: Vector2i) -> bool:
	return CELLS.has(cell)


static func is_buildable(cell: Vector2i, width: int, height: int) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return false
	return not is_path(cell)


static func cell_to_world(cell: Vector2i, cell_size: float) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


static func world_to_cell(pos: Vector2, cell_size: float) -> Vector2i:
	return Vector2i(int(floor(pos.x / cell_size)), int(floor(pos.y / cell_size)))


static func waypoint_world(index: int, cell_size: float) -> Vector2:
	if index < 0 or index >= CELLS.size():
		return cell_to_world(CELLS[CELLS.size() - 1], cell_size)
	return cell_to_world(CELLS[index], cell_size)
