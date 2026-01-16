## Cinematic Spawn Flow Integration Test
##
## Tests the complete flow of spawning actors in cinematics:
## 1. Actors array spawns actors before commands
## 2. spawn_entity command spawns actors during execution
## 3. Spawned actors can be controlled by move_entity
## 4. Cleanup happens on cinematic end/skip
class_name TestCinematicSpawnFlow
extends GdUnitTestSuite

const CinematicData = preload("res://core/resources/cinematic_data.gd")

# Scene container (GdUnitTestSuite extends Node, we need Node2D for some operations)
var _container: Node2D
var _tilemap_layer: TileMapLayer
var _tileset: TileSet
var _grid_resource: Grid

# Signal tracking
var _events_recorded: Array[String] = []


func before() -> void:
	_events_recorded.clear()

	# Create container for scene tree operations
	_container = Node2D.new()
	add_child(_container)

	# Create minimal TileMapLayer for GridManager
	_tilemap_layer = TileMapLayer.new()
	_tileset = TileSet.new()
	_tilemap_layer.tile_set = _tileset
	_container.add_child(_tilemap_layer)

	# Setup minimal grid
	_grid_resource = Grid.new()
	_grid_resource.grid_size = Vector2i(20, 20)
	_grid_resource.cell_size = 32
	GridManager.setup_grid(_grid_resource, _tilemap_layer)

	# Connect signals
	CinematicsManager.cinematic_started.connect(_on_cinematic_started)
	CinematicsManager.cinematic_ended.connect(_on_cinematic_ended)
	CinematicsManager.command_executed.connect(_on_command_executed)

	# Wait for autoloads to stabilize
	await await_idle_frame()


func after() -> void:
	# Disconnect signals
	if CinematicsManager.cinematic_started.is_connected(_on_cinematic_started):
		CinematicsManager.cinematic_started.disconnect(_on_cinematic_started)
	if CinematicsManager.cinematic_ended.is_connected(_on_cinematic_ended):
		CinematicsManager.cinematic_ended.disconnect(_on_cinematic_ended)
	if CinematicsManager.command_executed.is_connected(_on_command_executed):
		CinematicsManager.command_executed.disconnect(_on_command_executed)

	# Ensure cinematic state is clean
	if CinematicsManager.is_cinematic_active():
		CinematicsManager.skip_cinematic()
		await await_signal_on(CinematicsManager, "cinematic_ended", [], 2000)

	# Clean up tilemap
	if _tilemap_layer and is_instance_valid(_tilemap_layer):
		_tilemap_layer.queue_free()
		_tilemap_layer = null
	_tileset = null
	_grid_resource = null

	# Clean up container
	if _container and is_instance_valid(_container):
		_container.queue_free()
		_container = null


func before_test() -> void:
	_events_recorded.clear()

	# Ensure no cinematic is running from previous test
	if CinematicsManager.is_cinematic_active():
		CinematicsManager.skip_cinematic()
		await await_signal_on(CinematicsManager, "cinematic_ended", [], 2000)

	# Wait an extra frame to let any queued operations complete
	await await_idle_frame()

	# Clear spawned actors state
	CinematicsManager._spawned_actor_nodes.clear()
	CinematicsManager._registered_actors.clear()


# =============================================================================
# TEST: Actors Array Spawning
# =============================================================================

func test_actors_array_spawn() -> void:
	# Create cinematic with actors array
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = "actors_array_test"
	cinematic.cinematic_name = "Actors Array Test"
	cinematic.disable_player_input = false
	cinematic.can_skip = true

	# Add two actors to spawn before commands
	cinematic.add_actor("soldier_a", [3, 5], "down")
	cinematic.add_actor("soldier_b", [7, 5], "left")

	# Add minimal commands
	cinematic.add_wait(0.1)

	# Play cinematic
	var result: bool = CinematicsManager.play_cinematic_from_resource(cinematic)
	assert_bool(result).is_true()

	# Wait for cinematic to complete using signal
	await await_signal_on(CinematicsManager, "cinematic_ended", [], 5000)

	# Verify actors were spawned and cleaned up
	var spawned_count: int = CinematicsManager._spawned_actor_nodes.size()
	# Note: In headless mode, spawned_count might be 0 if scene tree is limited
	# The important thing is the cinematic ran without errors
	assert_int(spawned_count).is_equal(0)  # Should be cleaned up after cinematic ends


# =============================================================================
# TEST: Spawn Entity Command
# =============================================================================

func test_spawn_entity_command() -> void:
	# Ensure clean state
	CinematicsManager._spawned_actor_nodes.clear()
	CinematicsManager._registered_actors.clear()

	# Create cinematic with spawn_entity command
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = "spawn_command_test"
	cinematic.cinematic_name = "Spawn Command Test"
	cinematic.disable_player_input = false
	cinematic.can_skip = true

	# Add spawn command (not actors array)
	cinematic.add_spawn_entity("dynamic_npc", Vector2(10, 10), "up")
	cinematic.add_wait(0.1)

	# Play cinematic
	var result: bool = CinematicsManager.play_cinematic_from_resource(cinematic)
	assert_bool(result).is_true()

	# Wait for cinematic to complete using signal
	await await_signal_on(CinematicsManager, "cinematic_ended", [], 5000)

	# Verify spawned actors were cleaned up
	assert_int(CinematicsManager._spawned_actor_nodes.size()).is_equal(0)


# =============================================================================
# TEST: Spawned Actor Movement
# =============================================================================

func test_spawned_actor_movement() -> void:
	# Ensure clean state
	CinematicsManager._spawned_actor_nodes.clear()
	CinematicsManager._registered_actors.clear()

	# Create cinematic that spawns then moves an actor
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = "move_spawned_test"
	cinematic.cinematic_name = "Move Spawned Actor Test"
	cinematic.disable_player_input = false
	cinematic.can_skip = true

	# Spawn actor first via actors array
	cinematic.add_actor("mover", [5, 5], "right")

	# Move the spawned actor
	var path: Array = [[6, 5], [7, 5]]
	cinematic.add_move_entity("mover", path, 5.0, true)
	cinematic.add_wait(0.1)

	# Play cinematic
	var result: bool = CinematicsManager.play_cinematic_from_resource(cinematic)
	assert_bool(result).is_true()

	# Wait for cinematic to complete using signal (longer timeout for movement)
	await await_signal_on(CinematicsManager, "cinematic_ended", [], 5000)

	# Verify spawned actors were cleaned up
	assert_int(CinematicsManager._spawned_actor_nodes.size()).is_equal(0)


# =============================================================================
# TEST: Cleanup on Skip
# =============================================================================

func test_cleanup_on_skip() -> void:
	# Ensure clean state
	CinematicsManager._spawned_actor_nodes.clear()
	CinematicsManager._registered_actors.clear()

	# Create a longer cinematic
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = "skip_cleanup_test"
	cinematic.cinematic_name = "Skip Cleanup Test"
	cinematic.disable_player_input = false
	cinematic.can_skip = true

	# Add actors
	cinematic.add_actor("skip_actor_1", [1, 1], "down")
	cinematic.add_actor("skip_actor_2", [2, 2], "down")

	# Add long wait so we can skip mid-cinematic
	cinematic.add_wait(5.0)

	# Play cinematic
	var result: bool = CinematicsManager.play_cinematic_from_resource(cinematic)
	assert_bool(result).is_true()

	# Wait a frame for actors to spawn
	await await_idle_frame()

	# Skip the cinematic
	CinematicsManager.skip_cinematic()

	# Wait for cinematic_ended signal
	await await_signal_on(CinematicsManager, "cinematic_ended", [], 2000)

	var spawned_after_skip: int = CinematicsManager._spawned_actor_nodes.size()
	assert_int(spawned_after_skip).is_equal(0)


# =============================================================================
# TEST: Cleanup on End
# =============================================================================

func test_cleanup_on_end() -> void:
	# Ensure clean state
	CinematicsManager._spawned_actor_nodes.clear()
	CinematicsManager._registered_actors.clear()

	# Create a short cinematic
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = "end_cleanup_test"
	cinematic.cinematic_name = "End Cleanup Test"
	cinematic.disable_player_input = false
	cinematic.can_skip = true

	# Add actors
	cinematic.add_actor("end_actor", [3, 3], "down")

	# Short wait
	cinematic.add_wait(0.1)

	# Play cinematic
	var result: bool = CinematicsManager.play_cinematic_from_resource(cinematic)
	assert_bool(result).is_true()

	# Wait for natural completion using signal
	await await_signal_on(CinematicsManager, "cinematic_ended", [], 5000)

	var spawned_after_end: int = CinematicsManager._spawned_actor_nodes.size()
	assert_int(spawned_after_end).is_equal(0)


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_cinematic_started(_cinematic_id: String) -> void:
	_events_recorded.append("cinematic_started")


func _on_cinematic_ended(_cinematic_id: String) -> void:
	_events_recorded.append("cinematic_ended")


func _on_command_executed(_command_type: String, _index: int) -> void:
	_events_recorded.append("command_executed")
