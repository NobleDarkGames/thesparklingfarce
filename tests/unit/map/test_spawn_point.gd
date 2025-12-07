## Unit Tests for SpawnPoint Component
##
## Tests the spawn point marker system for map exploration.
## These tests focus on data structure and static utility functions.
class_name TestSpawnPoint
extends GdUnitTestSuite


const SpawnPointScript: GDScript = preload("res://core/components/spawn_point.gd")


# =============================================================================
# TEST FIXTURES
# =============================================================================

## Create a SpawnPoint node for testing
func _create_spawn_point(
	id: String,
	pos: Vector2 = Vector2.ZERO,
	face: String = "down",
	is_default: bool = false,
	is_caravan: bool = false
) -> Node:
	var spawn: Node = Marker2D.new()
	spawn.set_script(SpawnPointScript)
	spawn.spawn_id = id
	spawn.facing = face
	spawn.is_default = is_default
	spawn.is_caravan_spawn = is_caravan
	spawn.global_position = pos
	return spawn


## Create a test scene tree with multiple spawn points
func _create_test_scene() -> Node:
	var root: Node = Node2D.new()
	root.name = "TestMap"

	var spawns_container: Node = Node2D.new()
	spawns_container.name = "SpawnPoints"
	root.add_child(spawns_container)

	# Add various spawn points
	var spawn1: Node = _create_spawn_point("entrance", Vector2(160, 240), "up", true)
	var spawn2: Node = _create_spawn_point("from_castle", Vector2(80, 80), "down")
	var spawn3: Node = _create_spawn_point("caravan_spot", Vector2(200, 240), "down", false, true)

	spawns_container.add_child(spawn1)
	spawns_container.add_child(spawn2)
	spawns_container.add_child(spawn3)

	return root


# =============================================================================
# BASIC PROPERTY TESTS
# =============================================================================

func test_spawn_point_properties_set_correctly() -> void:
	var spawn: Node = _create_spawn_point("test_spawn", Vector2(32, 48), "left", true, false)
	auto_free(spawn)

	assert_str(spawn.spawn_id).is_equal("test_spawn")
	assert_str(spawn.facing).is_equal("left")
	assert_bool(spawn.is_default).is_true()
	assert_bool(spawn.is_caravan_spawn).is_false()


func test_spawn_point_defaults() -> void:
	var spawn: Node = Marker2D.new()
	spawn.set_script(SpawnPointScript)
	auto_free(spawn)

	assert_str(spawn.spawn_id).is_equal("")
	assert_str(spawn.facing).is_equal("down")
	assert_bool(spawn.is_default).is_false()
	assert_bool(spawn.is_caravan_spawn).is_false()


# =============================================================================
# GRID POSITION TESTS
# =============================================================================

func test_grid_position_calculation() -> void:
	# SpawnPoint uses tile_size = 32 (SF-authentic unified tiles)
	var spawn: Node = _create_spawn_point("test", Vector2(96, 64))
	auto_free(spawn)

	# 96 / 32 = 3, 64 / 32 = 2
	var grid_pos: Vector2i = spawn.grid_position
	assert_int(grid_pos.x).is_equal(3)
	assert_int(grid_pos.y).is_equal(2)


func test_grid_position_at_origin() -> void:
	var spawn: Node = _create_spawn_point("origin", Vector2.ZERO)
	auto_free(spawn)

	assert_object(spawn.grid_position).is_equal(Vector2i.ZERO)


func test_grid_position_with_offset() -> void:
	# Position at (48, 80) should floor to tile (1, 2) with 32px tiles
	var spawn: Node = _create_spawn_point("offset", Vector2(48, 80))
	auto_free(spawn)

	var grid_pos: Vector2i = spawn.grid_position
	assert_int(grid_pos.x).is_equal(1)
	assert_int(grid_pos.y).is_equal(2)


# =============================================================================
# SNAPPED POSITION TESTS
# =============================================================================

func test_snapped_position_centers_on_tile() -> void:
	# Position at (96, 64) with 32px tiles
	# grid (3, 2) -> snapped = (3 * 32 + 16, 2 * 32 + 16) = (112, 80)
	var spawn: Node = _create_spawn_point("test", Vector2(96, 64))
	auto_free(spawn)

	var snapped: Vector2 = spawn.snapped_position
	assert_float(snapped.x).is_equal_approx(112.0, 0.01)
	assert_float(snapped.y).is_equal_approx(80.0, 0.01)


# =============================================================================
# FACING VECTOR TESTS
# =============================================================================

func test_facing_vector_up() -> void:
	var spawn: Node = _create_spawn_point("test", Vector2.ZERO, "up")
	auto_free(spawn)

	assert_object(spawn.facing_vector).is_equal(Vector2i.UP)


func test_facing_vector_down() -> void:
	var spawn: Node = _create_spawn_point("test", Vector2.ZERO, "down")
	auto_free(spawn)

	assert_object(spawn.facing_vector).is_equal(Vector2i.DOWN)


func test_facing_vector_left() -> void:
	var spawn: Node = _create_spawn_point("test", Vector2.ZERO, "left")
	auto_free(spawn)

	assert_object(spawn.facing_vector).is_equal(Vector2i.LEFT)


func test_facing_vector_right() -> void:
	var spawn: Node = _create_spawn_point("test", Vector2.ZERO, "right")
	auto_free(spawn)

	assert_object(spawn.facing_vector).is_equal(Vector2i.RIGHT)


func test_facing_vector_invalid_defaults_to_down() -> void:
	var spawn: Node = _create_spawn_point("test", Vector2.ZERO, "diagonal")
	auto_free(spawn)

	assert_object(spawn.facing_vector).is_equal(Vector2i.DOWN)


# =============================================================================
# TO_DICT TESTS
# =============================================================================

func test_to_dict_includes_all_properties() -> void:
	var spawn: Node = _create_spawn_point("main", Vector2(160, 240), "up", true, true)
	auto_free(spawn)

	var dict: Dictionary = spawn.to_dict()

	assert_bool("grid_position" in dict).is_true()
	assert_str(dict["facing"]).is_equal("up")
	assert_bool(dict["is_default"]).is_true()
	assert_bool(dict["is_caravan_spawn"]).is_true()


# =============================================================================
# STATIC FINDER TESTS
# =============================================================================

func test_find_all_in_tree() -> void:
	var scene: Node = _create_test_scene()
	auto_free(scene)

	var spawns: Array = SpawnPointScript.find_all_in_tree(scene)

	assert_int(spawns.size()).is_equal(3)


func test_find_by_id_existing() -> void:
	var scene: Node = _create_test_scene()
	auto_free(scene)

	var spawn: Node = SpawnPointScript.find_by_id(scene, "from_castle")

	assert_object(spawn).is_not_null()
	assert_str(spawn.spawn_id).is_equal("from_castle")


func test_find_by_id_missing_returns_null() -> void:
	var scene: Node = _create_test_scene()
	auto_free(scene)

	var spawn: Node = SpawnPointScript.find_by_id(scene, "nonexistent")

	assert_object(spawn).is_null()


func test_find_default_returns_marked_default() -> void:
	var scene: Node = _create_test_scene()
	auto_free(scene)

	var default_spawn: Node = SpawnPointScript.find_default(scene)

	assert_object(default_spawn).is_not_null()
	assert_str(default_spawn.spawn_id).is_equal("entrance")
	assert_bool(default_spawn.is_default).is_true()


func test_find_default_fallback_when_none_marked() -> void:
	var root: Node = Node2D.new()
	auto_free(root)

	var spawn1: Node = _create_spawn_point("spawn1", Vector2.ZERO, "down", false)
	var spawn2: Node = _create_spawn_point("spawn2", Vector2(16, 0), "down", false)
	root.add_child(spawn1)
	root.add_child(spawn2)

	var default_spawn: Node = SpawnPointScript.find_default(root)

	# Should return first spawn point as fallback
	assert_object(default_spawn).is_not_null()


func test_find_default_returns_null_when_empty() -> void:
	var root: Node = Node2D.new()
	auto_free(root)

	var default_spawn: Node = SpawnPointScript.find_default(root)

	assert_object(default_spawn).is_null()


func test_find_caravan_spawn() -> void:
	var scene: Node = _create_test_scene()
	auto_free(scene)

	var caravan_spawn: Node = SpawnPointScript.find_caravan_spawn(scene)

	assert_object(caravan_spawn).is_not_null()
	assert_str(caravan_spawn.spawn_id).is_equal("caravan_spot")
	assert_bool(caravan_spawn.is_caravan_spawn).is_true()


func test_find_caravan_spawn_returns_null_when_none() -> void:
	var root: Node = Node2D.new()
	auto_free(root)

	var spawn: Node = _create_spawn_point("no_caravan", Vector2.ZERO)
	root.add_child(spawn)

	var caravan_spawn: Node = SpawnPointScript.find_caravan_spawn(root)

	assert_object(caravan_spawn).is_null()


# =============================================================================
# CONFIGURATION WARNINGS TESTS
# =============================================================================

func test_empty_spawn_id_generates_warning() -> void:
	var spawn: Node = Marker2D.new()
	spawn.set_script(SpawnPointScript)
	auto_free(spawn)

	var warnings: PackedStringArray = spawn._get_configuration_warnings()

	assert_int(warnings.size()).is_greater(0)
	assert_bool(warnings[0].contains("spawn_id")).is_true()


func test_valid_spawn_id_no_warning() -> void:
	var spawn: Node = _create_spawn_point("valid_id")
	auto_free(spawn)

	var warnings: PackedStringArray = spawn._get_configuration_warnings()

	assert_int(warnings.size()).is_equal(0)
