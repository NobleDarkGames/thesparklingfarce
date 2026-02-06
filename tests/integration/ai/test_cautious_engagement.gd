## Cautious Engagement Range Integration Test
##
## Tests that cautious AI units respect alert_range and engagement_range
## thresholds, creating guard-like behavior that doesn't chase forever.
##
## Validates three scenarios:
## A) Outside alert range - unit should NOT move
## B) Inside alert, outside engagement - unit should move but NOT attack
## C) Inside engagement range - unit should attack
class_name TestCautiousEngagement
extends GdUnitTestSuite

const UnitScript = preload("res://core/components/unit.gd")
const CharacterFactoryScript = preload("res://tests/fixtures/character_factory.gd")
const UnitFactoryScript = preload("res://tests/fixtures/unit_factory.gd")
const AIBehaviorFactoryScript = preload("res://tests/fixtures/ai_behavior_factory.gd")
const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")

# Test configuration
const ALERT_RANGE: int = 6
const ENGAGEMENT_RANGE: int = 3

# Units (recreated for each scenario)
var _cautious_unit: Unit
var _player_unit: Unit

# Tracking
var _unit_start_pos: Vector2i
var _combat_occurred: bool = false
var _tracker: SignalTracker

# Scene container for units (BattleManager needs Node2D)
var _units_container: Node2D

# Resources to clean up
var _tilemap_layer: TileMapLayer
var _tileset: TileSet
var _grid_resource: Grid
var _created_characters: Array[CharacterData] = []
var _created_classes: Array[ClassData] = []
var _created_behaviors: Array[AIBehaviorData] = []


func before_test() -> void:
	_combat_occurred = false
	_tracker = SignalTrackerScript.new()

	# Create units container (BattleManager needs Node2D)
	_units_container = Node2D.new()
	add_child(_units_container)

	_setup_grid()


func after_test() -> void:
	# Disconnect all tracked signals FIRST
	if _tracker:
		_tracker.disconnect_all()
		_tracker = null

	_cleanup_units()
	_cleanup_tilemap()
	_cleanup_resources()

	# Clear autoload state to prevent stale references between tests
	TurnManager.clear_battle()
	BattleManager.player_units.clear()
	BattleManager.enemy_units.clear()
	BattleManager.all_units.clear()
	GridManager.clear_grid()

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
	_grid_resource.grid_size = Vector2i(20, 10)
	_grid_resource.cell_size = 32
	GridManager.setup_grid(_grid_resource, [_tilemap_layer])


# =============================================================================
# SCENARIO A: Outside Alert Range - Should NOT move
# =============================================================================
func test_scenario_a_outside_alert_range_no_movement() -> void:
	# Create characters using CharacterFactory
	var cautious_character: CharacterData = CharacterFactoryScript.create_combatant("CautiousGuard", 80, 10, 15, 12, 10)
	_created_characters.append(cautious_character)
	var player_character: CharacterData = CharacterFactoryScript.create_combatant("Player", 100, 10, 15, 15, 10)
	player_character.is_hero = true
	_created_characters.append(player_character)

	# Create cautious behavior
	var cautious_ai: AIBehaviorData = _create_cautious_behavior()

	# Spawn cautious unit at (2, 5)
	_unit_start_pos = Vector2i(2, 5)
	_cautious_unit = UnitFactoryScript.spawn_unit(cautious_character, _unit_start_pos, "enemy", _units_container, cautious_ai)

	# Spawn player at (10, 5) - distance 8 (OUTSIDE alert_range of 6)
	_player_unit = UnitFactoryScript.spawn_unit(player_character, Vector2i(10, 5), "player", _units_container)

	# Setup BattleManager
	_setup_battle_manager()

	# Execute AI turn
	await _execute_cautious_turn()

	# Check results
	var unit_final_pos: Vector2i = _cautious_unit.grid_position
	var moved: bool = unit_final_pos != _unit_start_pos

	# Unit should NOT move and NOT attack when outside alert range
	assert_bool(moved).is_false()
	assert_bool(_combat_occurred).is_false()


# =============================================================================
# SCENARIO B: Inside Alert, Outside Engagement - Should move but NOT attack
# =============================================================================
func test_scenario_b_inside_alert_outside_engagement_move_no_attack() -> void:
	# Create characters using CharacterFactory
	var cautious_character: CharacterData = CharacterFactoryScript.create_combatant("CautiousGuard", 80, 10, 15, 12, 10)
	_created_characters.append(cautious_character)
	var player_character: CharacterData = CharacterFactoryScript.create_combatant("Player", 100, 10, 15, 15, 10)
	player_character.is_hero = true
	_created_characters.append(player_character)

	# Create cautious behavior
	var cautious_ai: AIBehaviorData = _create_cautious_behavior()

	# Spawn cautious unit at (2, 5)
	_unit_start_pos = Vector2i(2, 5)
	_cautious_unit = UnitFactoryScript.spawn_unit(cautious_character, _unit_start_pos, "enemy", _units_container, cautious_ai)

	# Spawn player at (8, 5) - distance 6 (INSIDE alert_range 6)
	_player_unit = UnitFactoryScript.spawn_unit(player_character, Vector2i(8, 5), "player", _units_container)

	# Setup BattleManager
	_setup_battle_manager()

	# Execute AI turn
	await _execute_cautious_turn()

	# Check results
	var unit_final_pos: Vector2i = _cautious_unit.grid_position
	var moved: bool = unit_final_pos != _unit_start_pos

	# Unit should move but NOT attack (can't reach attack range)
	assert_bool(moved).is_true()
	assert_bool(_combat_occurred).is_false()


# =============================================================================
# SCENARIO C: Inside Engagement Range - Should attack
# =============================================================================
func test_scenario_c_inside_engagement_range_should_attack() -> void:
	# Create characters using CharacterFactory
	var cautious_character: CharacterData = CharacterFactoryScript.create_combatant("CautiousGuard", 80, 10, 15, 12, 10)
	_created_characters.append(cautious_character)
	var player_character: CharacterData = CharacterFactoryScript.create_combatant("Player", 100, 10, 15, 15, 10)
	player_character.is_hero = true
	_created_characters.append(player_character)

	# Create cautious behavior
	var cautious_ai: AIBehaviorData = _create_cautious_behavior()

	# Spawn cautious unit at (2, 5)
	_unit_start_pos = Vector2i(2, 5)
	_cautious_unit = UnitFactoryScript.spawn_unit(cautious_character, _unit_start_pos, "enemy", _units_container, cautious_ai)

	# Spawn player at (4, 5) - distance 2 (INSIDE engagement_range of 3)
	_player_unit = UnitFactoryScript.spawn_unit(player_character, Vector2i(4, 5), "player", _units_container)

	# Setup BattleManager
	_setup_battle_manager()

	# Execute AI turn
	await _execute_cautious_turn()

	# Unit should attack when inside engagement range
	assert_bool(_combat_occurred).is_true()


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _create_cautious_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_cautious("test_cautious", ALERT_RANGE, ENGAGEMENT_RANGE)
	_created_behaviors.append(behavior)
	return behavior


func _setup_battle_manager() -> void:
	BattleManager.setup(_units_container, _units_container)
	BattleManager.player_units = [_player_unit]
	BattleManager.enemy_units = [_cautious_unit]
	BattleManager.all_units = [_cautious_unit, _player_unit]

	# Connect combat signal via tracker
	_tracker.track_with_callback(BattleManager.combat_resolved, _on_combat_resolved)


func _execute_cautious_turn() -> void:
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
	await brain.execute_with_behavior(_cautious_unit, context, _cautious_unit.ai_behavior)

	# Wait for movement to complete with bounded delay
	await await_millis(100)
	if _cautious_unit.is_moving():
		await await_millis(500)


func _on_combat_resolved(attacker: Unit, _defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	if attacker == _cautious_unit:
		_combat_occurred = true


func _cleanup_units() -> void:
	UnitFactoryScript.cleanup_unit(_cautious_unit)
	_cautious_unit = null
	UnitFactoryScript.cleanup_unit(_player_unit)
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
	_created_classes.clear()
	_created_behaviors.clear()
