## GridManager Integration Tests
##
## Tests the GridManager autoload functionality:
## - Grid setup and initialization
## - Occupancy tracking (set/clear/query)
## - A* pathfinding (path exists, blocked paths)
## - Movement range calculation
## - Coordinate conversion (world <-> grid)
## - Edge cases (out of bounds, invalid cells)
##
## Dependencies:
## - GridManager autoload (must be initialized)
## - Grid resource
## - CharacterFactory fixture
## - UnitFactory fixture
class_name TestGridManager
extends GdUnitTestSuite


const GridSetupScript = preload("res://tests/fixtures/grid_setup.gd")
const CharacterFactoryScript = preload("res://tests/fixtures/character_factory.gd")
const UnitFactoryScript = preload("res://tests/fixtures/unit_factory.gd")

var _grid_setup: GridSetup
var _container: Node2D
var _spawned_units: Array[Unit] = []


func before_test() -> void:
	_container = Node2D.new()
	add_child(_container)

	_grid_setup = GridSetupScript.new()
	_grid_setup.create_grid(_container, Vector2i(10, 10), 32)
	_spawned_units.clear()


func after_test() -> void:
	# Clean up any units
	for unit: Unit in _spawned_units:
		if unit and is_instance_valid(unit):
			UnitFactoryScript.cleanup_unit(unit)
	_spawned_units.clear()

	if _grid_setup:
		_grid_setup.cleanup()
		_grid_setup = null

	if _container and is_instance_valid(_container):
		_container.queue_free()
	_container = null


## Helper to spawn and track a unit for cleanup
func _spawn_unit(cell: Vector2i, faction: String = "player", unit_name: String = "Test") -> Unit:
	var character: CharacterData = CharacterFactoryScript.create_character(unit_name)
	var unit: Unit = UnitFactoryScript.spawn_unit(character, cell, faction, _container)
	_spawned_units.append(unit)
	return unit


# =============================================================================
# SETUP TESTS
# =============================================================================

func test_setup_grid_initializes_grid_reference() -> void:
	# Grid should be set after setup
	assert_object(GridManager.grid).is_not_null()


func test_setup_grid_initializes_tilemap_reference() -> void:
	# Tilemap should be set after setup
	assert_object(GridManager.tilemap).is_not_null()


func test_get_tile_size_returns_configured_cell_size() -> void:
	# Tile size should match grid configuration
	var tile_size: int = GridManager.get_tile_size()

	assert_int(tile_size).is_equal(32)


func test_grid_has_correct_dimensions() -> void:
	# Grid should have 10x10 dimensions as configured
	assert_int(GridManager.grid.grid_size.x).is_equal(10)
	assert_int(GridManager.grid.grid_size.y).is_equal(10)


# =============================================================================
# OCCUPANCY TESTS
# =============================================================================

func test_set_cell_occupied_marks_cell() -> void:
	# Spawn a unit which marks the cell as occupied
	var _unit: Unit = _spawn_unit(Vector2i(5, 5))

	var is_occupied: bool = GridManager.is_cell_occupied(Vector2i(5, 5))

	assert_bool(is_occupied).is_true()


func test_is_cell_occupied_returns_false_for_empty_cell() -> void:
	# Cell with no unit should not be occupied
	var is_occupied: bool = GridManager.is_cell_occupied(Vector2i(0, 0))

	assert_bool(is_occupied).is_false()


func test_clear_cell_occupied_unmarks_cell() -> void:
	# Spawn then cleanup to clear occupation
	var unit: Unit = _spawn_unit(Vector2i(3, 3))
	GridManager.clear_cell_occupied(Vector2i(3, 3))

	var is_occupied: bool = GridManager.is_cell_occupied(Vector2i(3, 3))

	assert_bool(is_occupied).is_false()

	# Remove from tracked list to avoid double cleanup
	_spawned_units.erase(unit)
	unit.queue_free()


func test_get_unit_at_cell_returns_occupying_unit() -> void:
	var unit: Unit = _spawn_unit(Vector2i(4, 4))

	var found_unit: Unit = GridManager.get_unit_at_cell(Vector2i(4, 4))

	assert_object(found_unit).is_same(unit)


func test_get_unit_at_cell_returns_null_for_empty_cell() -> void:
	var found_unit: Unit = GridManager.get_unit_at_cell(Vector2i(9, 9))

	assert_object(found_unit).is_null()


func test_move_unit_updates_occupancy() -> void:
	var unit: Unit = _spawn_unit(Vector2i(2, 2))
	var from_cell: Vector2i = Vector2i(2, 2)
	var to_cell: Vector2i = Vector2i(3, 3)

	GridManager.move_unit(unit, from_cell, to_cell)

	# Old cell should be empty
	assert_bool(GridManager.is_cell_occupied(from_cell)).is_false()
	# New cell should be occupied
	assert_bool(GridManager.is_cell_occupied(to_cell)).is_true()
	# Unit should be at new cell
	assert_object(GridManager.get_unit_at_cell(to_cell)).is_same(unit)


# =============================================================================
# PATHFINDING TESTS
# =============================================================================

func test_find_path_returns_valid_path() -> void:
	# Find path between two points on empty grid
	var path: Array[Vector2i] = GridManager.find_path(Vector2i(0, 0), Vector2i(3, 0))

	assert_array(path).is_not_empty()
	# Path should start at origin
	assert_int(path[0].x).is_equal(0)
	assert_int(path[0].y).is_equal(0)
	# Path should end at destination
	assert_int(path[-1].x).is_equal(3)
	assert_int(path[-1].y).is_equal(0)


func test_find_path_avoids_occupied_cells() -> void:
	# Place a blocker unit in the direct path
	var _blocker: Unit = _spawn_unit(Vector2i(2, 0), "enemy", "Blocker")

	# Path from (0,0) to (4,0) should go around the blocker
	var path: Array[Vector2i] = GridManager.find_path(Vector2i(0, 0), Vector2i(4, 0))

	# Path should exist but avoid the blocked cell
	assert_array(path).is_not_empty()
	# Should not contain the blocked cell
	var contains_blocked: bool = Vector2i(2, 0) in path
	assert_bool(contains_blocked).is_false()


func test_find_path_returns_empty_for_occupied_destination() -> void:
	# Place a unit at the destination
	var _target: Unit = _spawn_unit(Vector2i(5, 5), "enemy", "Target")

	# Pathfinding to an occupied cell should fail
	var path: Array[Vector2i] = GridManager.find_path(Vector2i(0, 0), Vector2i(5, 5))

	assert_array(path).is_empty()


func test_find_path_returns_empty_when_completely_blocked() -> void:
	# Surround cell (5,5) with units to make it unreachable
	# The cell itself is empty but cannot be reached
	var positions: Array[Vector2i] = [
		Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4),
		Vector2i(4, 5),                 Vector2i(6, 5),
		Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6)
	]
	for pos: Vector2i in positions:
		var _wall: Unit = _spawn_unit(pos, "enemy", "Wall")

	# Path to surrounded cell should fail
	var path: Array[Vector2i] = GridManager.find_path(Vector2i(0, 0), Vector2i(5, 5))

	assert_array(path).is_empty()


func test_find_path_allows_passing_through_allies() -> void:
	# Place an ally unit in the direct path
	var _ally: Unit = _spawn_unit(Vector2i(2, 0), "player", "Ally")

	# Path should be able to pass through ally (same faction)
	var path: Array[Vector2i] = GridManager.find_path(
		Vector2i(0, 0),
		Vector2i(4, 0),
		0,  # movement_type
		"player"  # mover_faction - same as ally
	)

	# Path should exist (can pass through ally)
	assert_array(path).is_not_empty()


# =============================================================================
# MOVEMENT RANGE TESTS (get_walkable_cells)
# =============================================================================

func test_get_walkable_cells_returns_cells_within_range() -> void:
	# Get cells within movement range 2 from center
	var cells: Array[Vector2i] = GridManager.get_walkable_cells(Vector2i(5, 5), 2)

	# Should include cells at distance 1
	assert_bool(Vector2i(5, 4) in cells).is_true()  # Up
	assert_bool(Vector2i(5, 6) in cells).is_true()  # Down
	assert_bool(Vector2i(4, 5) in cells).is_true()  # Left
	assert_bool(Vector2i(6, 5) in cells).is_true()  # Right

	# Should include cells at distance 2
	assert_bool(Vector2i(5, 3) in cells).is_true()  # 2 up
	assert_bool(Vector2i(3, 5) in cells).is_true()  # 2 left


func test_get_walkable_cells_excludes_origin() -> void:
	# Origin cell should NOT be in walkable cells (can't move to where you are)
	var cells: Array[Vector2i] = GridManager.get_walkable_cells(Vector2i(5, 5), 2)

	assert_bool(Vector2i(5, 5) in cells).is_false()


func test_get_walkable_cells_excludes_occupied_cells() -> void:
	# Place a unit that blocks a cell
	var _blocker: Unit = _spawn_unit(Vector2i(5, 4), "enemy", "Blocker")

	var cells: Array[Vector2i] = GridManager.get_walkable_cells(Vector2i(5, 5), 2)

	# Blocked cell should not be in reachable cells
	assert_bool(Vector2i(5, 4) in cells).is_false()


func test_get_walkable_cells_excludes_out_of_bounds() -> void:
	# Get walkable cells from corner - should not include out of bounds
	var cells: Array[Vector2i] = GridManager.get_walkable_cells(Vector2i(0, 0), 2)

	# Should not contain negative coordinates
	for cell: Vector2i in cells:
		assert_bool(cell.x >= 0).is_true()
		assert_bool(cell.y >= 0).is_true()


# =============================================================================
# COORDINATE CONVERSION TESTS
# =============================================================================

func test_cell_to_world_converts_coordinates() -> void:
	# Cell (3, 4) with 32px tiles should be at center of that cell
	var world_pos: Vector2 = GridManager.cell_to_world(Vector2i(3, 4))

	# 3 * 32 + 16 (center) = 112, 4 * 32 + 16 = 144
	assert_float(world_pos.x).is_equal(112.0)
	assert_float(world_pos.y).is_equal(144.0)


func test_world_to_cell_converts_coordinates() -> void:
	# World position (80, 64) should map to cell (2, 2)
	var grid_pos: Vector2i = GridManager.world_to_cell(Vector2(80, 64))

	# 80 / 32 = 2, 64 / 32 = 2
	assert_int(grid_pos.x).is_equal(2)
	assert_int(grid_pos.y).is_equal(2)


func test_coordinate_conversion_round_trip() -> void:
	# Converting cell -> world -> cell should return original cell
	var original_cell: Vector2i = Vector2i(7, 3)
	var world_pos: Vector2 = GridManager.cell_to_world(original_cell)
	var converted_cell: Vector2i = GridManager.world_to_cell(world_pos)

	assert_int(converted_cell.x).is_equal(original_cell.x)
	assert_int(converted_cell.y).is_equal(original_cell.y)


# =============================================================================
# DISTANCE AND RANGE TESTS
# =============================================================================

func test_get_distance_calculates_manhattan_distance() -> void:
	# Manhattan distance from (0,0) to (3,4) = 3 + 4 = 7
	var distance: int = GridManager.get_distance(Vector2i(0, 0), Vector2i(3, 4))

	assert_int(distance).is_equal(7)


func test_get_cells_in_range_returns_valid_cells() -> void:
	# Get cells within range 2 of center
	var cells: Array[Vector2i] = GridManager.get_cells_in_range(Vector2i(5, 5), 2)

	# Should include center cell
	assert_bool(Vector2i(5, 5) in cells).is_true()
	# Should include adjacent cells
	assert_bool(Vector2i(5, 4) in cells).is_true()
	assert_bool(Vector2i(4, 5) in cells).is_true()
	# Should include cells at distance 2
	assert_bool(Vector2i(5, 3) in cells).is_true()


func test_get_cells_in_range_band_excludes_dead_zone() -> void:
	# Range band (min=2, max=3) should exclude cells at distance < 2
	var cells: Array[Vector2i] = GridManager.get_cells_in_range_band(Vector2i(5, 5), 2, 3)

	# Center (distance 0) should NOT be included
	assert_bool(Vector2i(5, 5) in cells).is_false()
	# Adjacent (distance 1) should NOT be included
	assert_bool(Vector2i(5, 4) in cells).is_false()
	assert_bool(Vector2i(4, 5) in cells).is_false()
	# Distance 2 SHOULD be included
	assert_bool(Vector2i(5, 3) in cells).is_true()
	assert_bool(Vector2i(3, 5) in cells).is_true()


# =============================================================================
# BOUNDS CHECKING TESTS
# =============================================================================

func test_is_within_bounds_returns_true_for_valid_cell() -> void:
	var in_bounds: bool = GridManager.is_within_bounds(Vector2i(5, 5))

	assert_bool(in_bounds).is_true()


func test_is_within_bounds_returns_false_for_negative_coordinates() -> void:
	var in_bounds: bool = GridManager.is_within_bounds(Vector2i(-1, 5))

	assert_bool(in_bounds).is_false()


func test_is_within_bounds_returns_false_for_out_of_range_coordinates() -> void:
	# Grid is 10x10, so (10, 5) is out of bounds
	var in_bounds: bool = GridManager.is_within_bounds(Vector2i(10, 5))

	assert_bool(in_bounds).is_false()


func test_is_within_bounds_edge_case_at_max_valid() -> void:
	# (9, 9) should be valid in a 10x10 grid (0-9)
	var in_bounds: bool = GridManager.is_within_bounds(Vector2i(9, 9))

	assert_bool(in_bounds).is_true()


# =============================================================================
# EDGE CASES
# =============================================================================

func test_pathfinding_same_source_and_destination() -> void:
	# Path from a cell to itself returns just that cell
	var path: Array[Vector2i] = GridManager.find_path(Vector2i(5, 5), Vector2i(5, 5))

	# Should return path containing just the single cell
	assert_array(path).is_not_empty()
	assert_int(path.size()).is_equal(1)
	assert_int(path[0].x).is_equal(5)
	assert_int(path[0].y).is_equal(5)


func test_walkable_cells_with_zero_range() -> void:
	# Movement range of 0 should return empty (can't move anywhere)
	var cells: Array[Vector2i] = GridManager.get_walkable_cells(Vector2i(5, 5), 0)

	assert_array(cells).is_empty()


func test_multiple_units_occupy_different_cells() -> void:
	# Spawn multiple units at different positions
	var unit1: Unit = _spawn_unit(Vector2i(1, 1), "player", "Unit1")
	var unit2: Unit = _spawn_unit(Vector2i(2, 2), "player", "Unit2")
	var unit3: Unit = _spawn_unit(Vector2i(3, 3), "enemy", "Unit3")

	# All cells should be occupied with correct units
	assert_object(GridManager.get_unit_at_cell(Vector2i(1, 1))).is_same(unit1)
	assert_object(GridManager.get_unit_at_cell(Vector2i(2, 2))).is_same(unit2)
	assert_object(GridManager.get_unit_at_cell(Vector2i(3, 3))).is_same(unit3)


func test_clear_grid_resets_state() -> void:
	# Spawn a unit
	var _unit: Unit = _spawn_unit(Vector2i(5, 5))

	# Clear the grid
	GridManager.clear_grid()

	# Grid reference should be null
	assert_object(GridManager.grid).is_null()
	# Occupancy should be cleared
	assert_bool(GridManager.is_cell_occupied(Vector2i(5, 5))).is_false()

	# Re-setup grid for cleanup to work properly
	_grid_setup.create_grid(_container, Vector2i(10, 10), 32)
