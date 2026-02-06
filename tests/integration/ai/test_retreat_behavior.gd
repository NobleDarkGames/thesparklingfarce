## Retreat Behavior Integration Test
##
## Tests that AI units with retreat enabled will flee when HP drops
## below their retreat threshold, moving away from threats.
##
## Validates:
## - Unit at low HP retreats instead of attacking
## - Unit moves AWAY from enemy (increased distance)
## - No combat occurs during retreat
class_name TestRetreatBehavior
extends GdUnitTestSuite

const UnitScript = preload("res://core/components/unit.gd")
const AIBehaviorFactoryScript = preload("res://tests/fixtures/ai_behavior_factory.gd")
const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")

# Units
var _retreater_unit: Unit
var _threat_unit: Unit

# Tracking
var _retreater_start_pos: Vector2i
var _initial_distance: int
var _combat_occurred: bool = false
var _tracker: SignalTracker

# Scene container for units (BattleManager needs Node2D)
var _units_container: Node2D

# Resources to clean up
var _tilemap_layer: TileMapLayer
var _tileset: TileSet
var _grid_resource: Grid
var _created_characters: Array[CharacterData] = []
var _created_behaviors: Array[AIBehaviorData] = []


func before() -> void:
	_combat_occurred = false
	_tracker = SignalTrackerScript.new()

	# Create units container (BattleManager needs Node2D)
	_units_container = Node2D.new()
	add_child(_units_container)

	# Create minimal TileMapLayer for GridManager
	_tilemap_layer = TileMapLayer.new()
	_tileset = TileSet.new()
	_tilemap_layer.tile_set = _tileset
	_units_container.add_child(_tilemap_layer)

	# Setup grid (larger to allow retreat movement)
	_grid_resource = Grid.new()
	_grid_resource.grid_size = Vector2i(20, 15)
	_grid_resource.cell_size = 32
	GridManager.setup_grid(_grid_resource, [_tilemap_layer])


func after() -> void:
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


func test_wounded_unit_retreats_from_threat() -> void:
	# Create retreater character
	var retreater_character: CharacterData = _create_character("Retreater", 100, 10, 15, 10, 12)

	# Create threat character
	var threat_character: CharacterData = _create_character("Threat", 100, 10, 20, 15, 8)
	threat_character.is_hero = true

	# Create retreat-enabled behavior
	var retreater_ai: AIBehaviorData = _create_retreat_behavior()

	# Spawn retreater at position (10, 7) - center of map, room to retreat
	_retreater_start_pos = Vector2i(10, 7)
	_retreater_unit = _spawn_unit(retreater_character, _retreater_start_pos, "enemy", retreater_ai)

	# Set HP to 50% (below the 60% retreat threshold)
	_retreater_unit.stats.current_hp = 50

	# Spawn threat at position (7, 7) - distance 3, close enough to trigger retreat
	_threat_unit = _spawn_unit(threat_character, Vector2i(7, 7), "player", null)

	# Record initial distance
	_initial_distance = _get_distance(_retreater_unit, _threat_unit)

	# Setup BattleManager
	BattleManager.setup(_units_container, _units_container)
	BattleManager.player_units = [_threat_unit]
	BattleManager.enemy_units = [_retreater_unit]
	BattleManager.all_units = [_retreater_unit, _threat_unit]

	# Connect combat signal via tracker
	_tracker.track_with_callback(BattleManager.combat_resolved, _on_combat_resolved)

	# Run the AI turn
	await _execute_retreater_turn()

	# Wait for AI processing to complete
	await await_millis(100)

	# Validate results
	var retreater_final_pos: Vector2i = _retreater_unit.grid_position
	var final_distance: int = _get_distance(_retreater_unit, _threat_unit)
	var distance_change: int = final_distance - _initial_distance

	# Unit should NOT attack when retreating
	assert_bool(_combat_occurred).is_false()

	# Unit should have moved
	assert_bool(retreater_final_pos != _retreater_start_pos).is_true()

	# Unit should move AWAY from threat (increased distance)
	assert_bool(distance_change > 0).is_true()


func _create_character(p_name: String, hp: int, mp: int, str_val: int, def_val: int, agi: int) -> CharacterData:
	var character: CharacterData = CharacterFactory.create_combatant(p_name, hp, mp, str_val, def_val, agi)
	character.character_class.movement_range = 5
	_created_characters.append(character)
	return character


func _create_retreat_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_retreat_when_hurt("test_retreater", 60)
	_created_behaviors.append(behavior)
	return behavior


func _spawn_unit(character: CharacterData, cell: Vector2i, p_faction: String, p_ai_behavior: AIBehaviorData) -> Unit:
	return UnitFactory.spawn_unit(character, cell, p_faction, _units_container, p_ai_behavior)


func _get_distance(unit_a: Unit, unit_b: Unit) -> int:
	return GridManager.grid.get_manhattan_distance(unit_a.grid_position, unit_b.grid_position)


func _execute_retreater_turn() -> void:
	var hp_percent: float = 100.0 * _retreater_unit.stats.current_hp / _retreater_unit.stats.max_hp

	var context: Dictionary = {
		"player_units": BattleManager.player_units,
		"enemy_units": BattleManager.enemy_units,
		"neutral_units": [],
		"turn_number": 1,
		"unit_hp_percent": hp_percent,
		"ai_delays": {"after_movement": 0.0, "before_attack": 0.0}
	}

	var ConfigurableAIBrainScript: GDScript = load("res://core/systems/ai/configurable_ai_brain.gd")
	var brain: AIBrain = ConfigurableAIBrainScript.get_instance()
	await brain.execute_with_behavior(_retreater_unit, context, _retreater_unit.ai_behavior)

	# Wait for movement to complete with bounded delay
	await await_millis(100)
	if _retreater_unit.is_moving():
		await await_millis(500)


func _on_combat_resolved(attacker: Unit, _defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	if attacker == _retreater_unit:
		_combat_occurred = true


func _cleanup_units() -> void:
	UnitFactory.cleanup_unit(_retreater_unit)
	_retreater_unit = null
	UnitFactory.cleanup_unit(_threat_unit)
	_threat_unit = null


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
