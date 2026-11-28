extends GutTest


func test_path_cells_are_not_buildable() -> void:
	assert_true(TdPath.is_path(Vector2i(0, 5)), "start is path")
	assert_false(TdPath.is_buildable(Vector2i(0, 5)), "path blocked")
	assert_true(TdPath.is_buildable(Vector2i(1, 1)), "empty cell ok")
	assert_false(TdPath.is_buildable(Vector2i(-1, 0)), "oob")


func test_world_cell_roundtrip() -> void:
	var cell := Vector2i(3, 4)
	var world := TdPath.cell_to_world(cell, 40.0)
	assert_eq(TdPath.world_to_cell(world, 40.0), cell, "round trip")
