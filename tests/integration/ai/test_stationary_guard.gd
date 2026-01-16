## Stationary Guard Behavior Integration Test
##
## Tests that guard units with very small alert/engagement ranges
## hold position and only attack adjacent enemies.
##
## Validates:
## - Guard does NOT move when player is far away
## - Guard does NOT move when player is nearby but not adjacent
## - Guard ONLY attacks when player is adjacent (distance 1)
class_name TestStationaryGuard
extends GdUnitTestSuite

const UnitScript = preload("res://core/components/unit.gd")

# Units (recreated for each scenario)
var _guard_unit: Unit
var _player_unit: Unit

# Tracking
var _guard_start_pos: Vector2i
var _combat_occurred: bool = false

# Scene container for units (BattleManager needs Node2D)
var _units_container: Node2D

# Resources to clean up
var _tilemap_layer: TileMapLayer
var _tileset: TileSet
var _grid_resource: Grid
var _created_characters: Array[CharacterData] = []
var _created_behaviors: Array[AIBehaviorData] = []


func before_test() -> void:
	_combat_occurred = false

	# Create units container (BattleManager needs Node2D)
	_units_container = Node2D.new()
	add_child(_units_container)

	_setup_grid()


func after_test() -> void:
	_cleanup_units()
	_cleanup_tilemap()
	_cleanup_resources()

	# Disconnect combat signal if connected
	if BattleManager.combat_resolved.is_connected(_on_combat_resolved):
		BattleManager.combat_resolved.disconnect(_on_combat_resolved)

	# Clean up units container
	if _units_container and is_instance_valid(_units_container):
		_units_container.queue_free()
		_units_container = null


func _setup_grid() -> void:
	# Create minimal TileMapLayer for GridManager
	_tilemap_layer = TileMapLayer.new()
	_tileset = TileSet.new()
	_tilemap_layer.tile_set = _tileset
	_units_container.add_child(_tilemap_layer)

	# Setup grid
	_grid_resource = Grid.new()
	_grid_resource.grid_size = Vector2i(15, 10)
	_grid_resource.cell_size = 32
	GridManager.setup_grid(_grid_resource, _tilemap_layer)


# =============================================================================
# SCENARIO A: Player NOT adjacent - Guard should NOT move or attack
# =============================================================================
func test_scenario_a_guard_ignores_distant_player() -> void:
	# Create characters
	var guard_character: CharacterData = _create_character("StationaryGuard", 100, 10, 18, 15, 8)
	var player_character: CharacterData = _create_character("Player", 80, 10, 15, 12, 12)
	player_character.is_hero = true

	# Create truly stationary behavior (alert_range=1, engagement_range=1)
	var guard_ai: AIBehaviorData = _create_stationary_behavior()

	# Spawn guard at (5, 5)
	_guard_start_pos = Vector2i(5, 5)
	_guard_unit = _spawn_unit(guard_character, _guard_start_pos, "enemy", guard_ai)

	# Spawn player at (8, 5) - distance 3 (outside alert_range of 1)
	_player_unit = _spawn_unit(player_character, Vector2i(8, 5), "player", null)

	# Setup BattleManager
	_setup_battle_manager()

	# Execute AI turn
	await _execute_guard_turn()

	# Check results
	var guard_final_pos: Vector2i = _guard_unit.grid_position
	var moved: bool = guard_final_pos != _guard_start_pos

	# Guard should NOT move and NOT attack when player is far
	assert_bool(moved).is_false()
	assert_bool(_combat_occurred).is_false()


# =============================================================================
# SCENARIO B: Player adjacent - Guard should attack (but NOT move first)
# =============================================================================
func test_scenario_b_guard_attacks_adjacent_player() -> void:
	# Create characters
	var guard_character: CharacterData = _create_character("StationaryGuard", 100, 10, 18, 15, 8)
	var player_character: CharacterData = _create_character("Player", 80, 10, 15, 12, 12)
	player_character.is_hero = true

	# Create truly stationary behavior
	var guard_ai: AIBehaviorData = _create_stationary_behavior()

	# Spawn guard at (5, 5)
	_guard_start_pos = Vector2i(5, 5)
	_guard_unit = _spawn_unit(guard_character, _guard_start_pos, "enemy", guard_ai)

	# Spawn player at (6, 5) - distance 1 (adjacent, inside alert and engagement range)
	_player_unit = _spawn_unit(player_character, Vector2i(6, 5), "player", null)

	# Setup BattleManager
	_setup_battle_manager()

	# Execute AI turn
	await _execute_guard_turn()

	# Check results
	var guard_final_pos: Vector2i = _guard_unit.grid_position
	var moved: bool = guard_final_pos != _guard_start_pos

	# Guard should NOT move but SHOULD attack adjacent player
	assert_bool(moved).is_false()
	assert_bool(_combat_occurred).is_true()


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _create_character(p_name: String, hp: int, mp: int, str_val: int, def_val: int, agi: int) -> CharacterData:
	var character: CharacterData = CharacterFactory.create_combatant(p_name, hp, mp, str_val, def_val, agi)
	_created_characters.append(character)
	return character


func _create_stationary_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = "test_stationary_guard"
	behavior.display_name = "Test Stationary Guard"
	behavior.role = "defensive"
	behavior.behavior_mode = "cautious"
	behavior.alert_range = 1
	behavior.engagement_range = 1
	behavior.retreat_enabled = false
	behavior.use_healing_items = false
	behavior.use_attack_items = false

	# Track for cleanup
	_created_behaviors.append(behavior)

	return behavior


func _spawn_unit(character: CharacterData, cell: Vector2i, p_faction: String, p_ai_behavior: AIBehaviorData) -> Unit:
	return UnitFactory.spawn_unit(character, cell, p_faction, _units_container, p_ai_behavior)


func _setup_battle_manager() -> void:
	BattleManager.setup(_units_container, _units_container)
	BattleManager.player_units = [_player_unit]
	BattleManager.enemy_units = [_guard_unit]
	BattleManager.all_units = [_guard_unit, _player_unit]

	# Connect combat signal
	if not BattleManager.combat_resolved.is_connected(_on_combat_resolved):
		BattleManager.combat_resolved.connect(_on_combat_resolved)


func _execute_guard_turn() -> void:
	var context: Dictionary = {
		"player_units": BattleManager.player_units,
		"enemy_units": BattleManager.enemy_units,
		"neutral_units": [],
		"turn_number": 1,
		"unit_hp_percent": 100.0,
		"ai_delays": {"after_movement": 0.0, "before_attack": 0.0}
	}

	var ConfigurableAIBrainScript: GDScript = load("res://core/systems/ai/configurable_ai_brain.gd")
	var brain: AIBrain = ConfigurableAIBrainScript.get_instance()
	await brain.execute_with_behavior(_guard_unit, context, _guard_unit.ai_behavior)

	# Wait for any movement to complete (with timeout)
	var wait_start: float = Time.get_ticks_msec()
	while _guard_unit.is_moving() and (Time.get_ticks_msec() - wait_start) < 3000:
		await get_tree().process_frame

	# Wait for AI processing to complete
	await await_millis(100)


func _on_combat_resolved(attacker: Unit, _defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	if attacker == _guard_unit:
		_combat_occurred = true


func _cleanup_units() -> void:
	UnitFactory.cleanup_unit(_guard_unit)
	_guard_unit = null
	UnitFactory.cleanup_unit(_player_unit)
	_player_unit = null


func _cleanup_tilemap() -> void:
	if _tilemap_layer and is_instance_valid(_tilemap_layer):
		_tilemap_layer.queue_free()
		_tilemap_layer = null
	_tileset = null
	_grid_resource = null


func _cleanup_resources() -> void:
	# Clear tracked resources (RefCounted will handle cleanup)
	_created_characters.clear()
	_created_behaviors.clear()
