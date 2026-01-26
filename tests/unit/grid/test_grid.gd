## Unit Tests for Grid Resource
##
## Tests the Grid resource which handles coordinate conversion, bounds checking,
## and utility functions for tactical movement in battle maps.
## Pure calculation tests - no scene dependencies.
class_name TestGrid
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

## Create a test Grid instance with specified dimensions
## Defaults to 10x10 grid with 32px cells (standard test configuration)
func _create_test_grid(
	width: int = 10,
	height: int = 10,
	cell_size_px: int = 32
) -> Grid:
	var grid: Grid = Grid.new()
	grid.grid_size = Vector2i(width, height)
	grid.cell_size = cell_size_px
	return grid


# =============================================================================
# BOUNDS CHECKING TESTS
# =============================================================================

func test_is_within_bounds_returns_true_for_valid_position() -> void:
	var grid: Grid = _create_test_grid()

	var in_bounds: bool = grid.is_within_bounds(Vector2i(5, 5))

	assert_bool(in_bounds).is_true()


func test_is_within_bounds_returns_false_for_x_out_of_bounds() -> void:
	var grid: Grid = _create_test_grid()

	var out_of_bounds: bool = grid.is_within_bounds(Vector2i(15, 5))

	assert_bool(out_of_bounds).is_false()


func test_is_within_bounds_returns_false_for_y_out_of_bounds() -> void:
	var grid: Grid = _create_test_grid()

	var out_of_bounds: bool = grid.is_within_bounds(Vector2i(5, 15))

	assert_bool(out_of_bounds).is_false()


func test_is_within_bounds_returns_false_for_negative_x() -> void:
	var grid: Grid = _create_test_grid()

	var out_of_bounds: bool = grid.is_within_bounds(Vector2i(-1, 5))

	assert_bool(out_of_bounds).is_false()


func test_is_within_bounds_returns_false_for_negative_y() -> void:
	var grid: Grid = _create_test_grid()

	var out_of_bounds: bool = grid.is_within_bounds(Vector2i(5, -1))

	assert_bool(out_of_bounds).is_false()


func test_is_within_bounds_returns_true_for_origin() -> void:
	var grid: Grid = _create_test_grid()

	var in_bounds: bool = grid.is_within_bounds(Vector2i(0, 0))

	assert_bool(in_bounds).is_true()


func test_is_within_bounds_returns_true_for_max_valid_position() -> void:
	var grid: Grid = _create_test_grid()

	# For a 10x10 grid, max valid position is (9, 9)
	var in_bounds: bool = grid.is_within_bounds(Vector2i(9, 9))

	assert_bool(in_bounds).is_true()


func test_is_within_bounds_returns_false_for_edge_position() -> void:
	var grid: Grid = _create_test_grid()

	# For a 10x10 grid, (10, 10) is out of bounds
	var out_of_bounds: bool = grid.is_within_bounds(Vector2i(10, 10))

	assert_bool(out_of_bounds).is_false()


# =============================================================================
# MANHATTAN DISTANCE TESTS
# =============================================================================

func test_manhattan_distance_basic_calculation() -> void:
	var grid: Grid = _create_test_grid()

	# Distance from (0,0) to (3,4) = |3-0| + |4-0| = 7
	var distance: int = grid.get_manhattan_distance(Vector2i(0, 0), Vector2i(3, 4))

	assert_int(distance).is_equal(7)


func test_manhattan_distance_same_position_is_zero() -> void:
	var grid: Grid = _create_test_grid()

	var distance: int = grid.get_manhattan_distance(Vector2i(5, 5), Vector2i(5, 5))

	assert_int(distance).is_equal(0)


func test_manhattan_distance_horizontal_only() -> void:
	var grid: Grid = _create_test_grid()

	# Distance from (2,3) to (7,3) = |7-2| + |3-3| = 5
	var distance: int = grid.get_manhattan_distance(Vector2i(2, 3), Vector2i(7, 3))

	assert_int(distance).is_equal(5)


func test_manhattan_distance_vertical_only() -> void:
	var grid: Grid = _create_test_grid()

	# Distance from (4,1) to (4,8) = |4-4| + |8-1| = 7
	var distance: int = grid.get_manhattan_distance(Vector2i(4, 1), Vector2i(4, 8))

	assert_int(distance).is_equal(7)


func test_manhattan_distance_is_symmetric() -> void:
	var grid: Grid = _create_test_grid()

	var dist_a_to_b: int = grid.get_manhattan_distance(Vector2i(1, 2), Vector2i(5, 7))
	var dist_b_to_a: int = grid.get_manhattan_distance(Vector2i(5, 7), Vector2i(1, 2))

	assert_int(dist_a_to_b).is_equal(dist_b_to_a)


# =============================================================================
# NEIGHBOR RETRIEVAL TESTS
# =============================================================================

func test_get_neighbors_center_has_4_neighbors() -> void:
	var grid: Grid = _create_test_grid()

	var neighbors: Array[Vector2i] = grid.get_neighbors(Vector2i(5, 5))

	assert_int(neighbors.size()).is_equal(4)


func test_get_neighbors_center_contains_correct_positions() -> void:
	var grid: Grid = _create_test_grid()

	var neighbors: Array[Vector2i] = grid.get_neighbors(Vector2i(5, 5))

	# Should contain up, down, left, right neighbors
	assert_bool(Vector2i(5, 4) in neighbors).is_true()  # up
	assert_bool(Vector2i(5, 6) in neighbors).is_true()  # down
	assert_bool(Vector2i(4, 5) in neighbors).is_true()  # left
	assert_bool(Vector2i(6, 5) in neighbors).is_true()  # right


func test_get_neighbors_corner_has_2_neighbors() -> void:
	var grid: Grid = _create_test_grid()

	var neighbors: Array[Vector2i] = grid.get_neighbors(Vector2i(0, 0))

	assert_int(neighbors.size()).is_equal(2)


func test_get_neighbors_corner_contains_correct_positions() -> void:
	var grid: Grid = _create_test_grid()

	var neighbors: Array[Vector2i] = grid.get_neighbors(Vector2i(0, 0))

	# Top-left corner only has right and down neighbors
	assert_bool(Vector2i(1, 0) in neighbors).is_true()  # right
	assert_bool(Vector2i(0, 1) in neighbors).is_true()  # down


func test_get_neighbors_edge_has_3_neighbors() -> void:
	var grid: Grid = _create_test_grid()

	# Position on top edge (not corner)
	var neighbors: Array[Vector2i] = grid.get_neighbors(Vector2i(5, 0))

	assert_int(neighbors.size()).is_equal(3)


func test_get_neighbors_bottom_right_corner() -> void:
	var grid: Grid = _create_test_grid()

	var neighbors: Array[Vector2i] = grid.get_neighbors(Vector2i(9, 9))

	assert_int(neighbors.size()).is_equal(2)
	assert_bool(Vector2i(8, 9) in neighbors).is_true()  # left
	assert_bool(Vector2i(9, 8) in neighbors).is_true()  # up


# =============================================================================
# COORDINATE CONVERSION TESTS
# =============================================================================

func test_map_to_local_converts_grid_to_world_center() -> void:
	var grid: Grid = _create_test_grid()
	# Default cell_size is 32, _half_cell_size is 16

	var world_pos: Vector2 = grid.map_to_local(Vector2i(2, 3))

	# Should be (2*32 + 16, 3*32 + 16) = (80, 112) for center of cell
	assert_vector(world_pos).is_equal(Vector2(80, 112))


func test_map_to_local_origin_cell() -> void:
	var grid: Grid = _create_test_grid()

	var world_pos: Vector2 = grid.map_to_local(Vector2i(0, 0))

	# (0*32 + 16, 0*32 + 16) = (16, 16)
	assert_vector(world_pos).is_equal(Vector2(16, 16))


func test_map_to_local_with_custom_cell_size() -> void:
	var grid: Grid = _create_test_grid(10, 10, 64)

	var world_pos: Vector2 = grid.map_to_local(Vector2i(1, 1))

	# (1*64 + 32, 1*64 + 32) = (96, 96)
	assert_vector(world_pos).is_equal(Vector2(96, 96))


func test_local_to_map_converts_world_to_grid() -> void:
	var grid: Grid = _create_test_grid()
	# Default cell_size is 32

	var cell_pos: Vector2i = grid.local_to_map(Vector2(80, 112))

	assert_int(cell_pos.x).is_equal(2)
	assert_int(cell_pos.y).is_equal(3)


func test_local_to_map_origin_position() -> void:
	var grid: Grid = _create_test_grid()

	var cell_pos: Vector2i = grid.local_to_map(Vector2(16, 16))

	assert_int(cell_pos.x).is_equal(0)
	assert_int(cell_pos.y).is_equal(0)


func test_local_to_map_edge_of_cell() -> void:
	var grid: Grid = _create_test_grid()

	# Position at (31, 31) should still be cell (0, 0)
	var cell_pos: Vector2i = grid.local_to_map(Vector2(31, 31))

	assert_int(cell_pos.x).is_equal(0)
	assert_int(cell_pos.y).is_equal(0)


func test_local_to_map_next_cell_boundary() -> void:
	var grid: Grid = _create_test_grid()

	# Position at (32, 32) should be cell (1, 1)
	var cell_pos: Vector2i = grid.local_to_map(Vector2(32, 32))

	assert_int(cell_pos.x).is_equal(1)
	assert_int(cell_pos.y).is_equal(1)


func test_coordinate_conversion_roundtrip() -> void:
	var grid: Grid = _create_test_grid()

	# Converting grid -> world -> grid should return to same position
	var original: Vector2i = Vector2i(3, 5)
	var world_pos: Vector2 = grid.map_to_local(original)
	var back_to_grid: Vector2i = grid.local_to_map(world_pos)

	assert_int(back_to_grid.x).is_equal(original.x)
	assert_int(back_to_grid.y).is_equal(original.y)


# =============================================================================
# CELLS IN RANGE TESTS
# =============================================================================

func test_get_cells_in_range_returns_5_for_range_1() -> void:
	var grid: Grid = _create_test_grid()

	# Range 1 from center should give 5 cells (center + 4 neighbors)
	var cells: Array[Vector2i] = grid.get_cells_in_range(Vector2i(5, 5), 1)

	assert_int(cells.size()).is_equal(5)


func test_get_cells_in_range_includes_center() -> void:
	var grid: Grid = _create_test_grid()

	var cells: Array[Vector2i] = grid.get_cells_in_range(Vector2i(5, 5), 1)

	assert_bool(Vector2i(5, 5) in cells).is_true()


func test_get_cells_in_range_diamond_pattern() -> void:
	var grid: Grid = _create_test_grid()

	# Range 2 should form a diamond pattern (13 cells for center position)
	var cells: Array[Vector2i] = grid.get_cells_in_range(Vector2i(5, 5), 2)

	# Diamond pattern for range 2: 1 + 3 + 5 + 3 + 1 = 13 cells
	assert_int(cells.size()).is_equal(13)


func test_get_cells_in_range_respects_bounds() -> void:
	var grid: Grid = _create_test_grid()

	# Range 3 from corner (0,0) should have limited cells due to bounds
	var cells: Array[Vector2i] = grid.get_cells_in_range(Vector2i(0, 0), 3)

	# All returned cells should be within bounds
	for cell: Vector2i in cells:
		assert_bool(grid.is_within_bounds(cell)).is_true()


func test_get_cells_in_range_corner_position() -> void:
	var grid: Grid = _create_test_grid()

	# Range 1 from corner (0,0) should have 3 cells (corner + 2 neighbors)
	var cells: Array[Vector2i] = grid.get_cells_in_range(Vector2i(0, 0), 1)

	assert_int(cells.size()).is_equal(3)


func test_get_cells_in_range_zero_returns_only_center() -> void:
	var grid: Grid = _create_test_grid()

	var cells: Array[Vector2i] = grid.get_cells_in_range(Vector2i(5, 5), 0)

	assert_int(cells.size()).is_equal(1)
	assert_bool(Vector2i(5, 5) in cells).is_true()


func test_get_cells_in_range_large_range() -> void:
	var grid: Grid = _create_test_grid()

	# Range 5 from center of 10x10 grid
	var cells: Array[Vector2i] = grid.get_cells_in_range(Vector2i(5, 5), 5)

	# Should have many cells but all within bounds
	assert_int(cells.size()).is_greater(20)
	for cell: Vector2i in cells:
		assert_bool(grid.is_within_bounds(cell)).is_true()
