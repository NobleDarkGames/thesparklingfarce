## Ranged AI Positioning Integration Test
##
## Tests that AI units with ranged weapons (bows) properly position themselves
## within their weapon's attack range band, avoiding the dead zone.
##
## Validates:
## - Archers don't walk into melee range when they have a ranged weapon
## - AI moves to valid attack position (min_range <= distance <= max_range)
## - AI attacks after positioning correctly
class_name TestRangedAiPositioning
extends GdUnitTestSuite

const UnitScript = preload("res://core/components/unit.gd")
const AIBehaviorFactoryScript = preload("res://tests/fixtures/ai_behavior_factory.gd")
const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")

# Units
var _archer_unit: Unit
var _target_unit: Unit

# Tracking
var _archer_start_pos: Vector2i
var _archer_final_pos: Vector2i
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
var _created_items: Array[ItemData] = []


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

	# Setup grid (larger to allow movement testing)
	_grid_resource = Grid.new()
	_grid_resource.grid_size = Vector2i(15, 10)
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


func test_archer_maintains_attack_range_avoids_melee() -> void:
	# Create archer character
	var archer_character: CharacterData = _create_character("TestArcher", 30, 10, 15, 10, 12)

	# Create target character (tanky so it survives)
	var target_character: CharacterData = _create_character("TestTarget", 100, 10, 10, 20, 5)
	target_character.is_hero = true

	# Create opportunistic archer AI behavior
	var archer_ai: AIBehaviorData = _create_archer_behavior()

	# Spawn archer at position (2, 5) - will need to move to attack
	_archer_start_pos = Vector2i(2, 5)
	_archer_unit = _spawn_unit(archer_character, _archer_start_pos, "enemy", archer_ai)

	# Create and equip a BOW with range 2-4 (dead zone at distance 1)
	var bow: ItemData = ItemData.new()
	bow.item_name = "Test Bow"
	bow.item_type = ItemData.ItemType.WEAPON
	bow.attack_power = 10
	bow.min_attack_range = 2
	bow.max_attack_range = 4
	bow.hit_rate = 90
	bow.critical_rate = 5
	_archer_unit.stats.cached_weapon = bow
	_created_items.append(bow)

	# Spawn target at position (8, 5) - distance of 6 from archer
	_target_unit = _spawn_unit(target_character, Vector2i(8, 5), "player", null)

	# Setup BattleManager
	BattleManager.setup(_units_container, _units_container)
	BattleManager.player_units = [_target_unit]
	BattleManager.enemy_units = [_archer_unit]
	BattleManager.all_units = [_archer_unit, _target_unit]

	# Connect combat signal via tracker
	_tracker.track_with_callback(BattleManager.combat_resolved, _on_combat_resolved)

	# Run the AI turn
	await _execute_archer_turn()

	# Record final position
	_archer_final_pos = _archer_unit.grid_position

	# Validate positioning
	var final_distance: int = _get_distance(_archer_unit, _target_unit)
	var min_range: int = _archer_unit.stats.get_weapon_min_range()
	var max_range: int = _archer_unit.stats.get_weapon_max_range()

	var in_valid_range: bool = final_distance >= min_range and final_distance <= max_range
	var in_dead_zone: bool = final_distance < min_range

	# Archer should NOT be in dead zone
	assert_bool(in_dead_zone).is_false()

	# Archer should be in valid attack range
	assert_bool(in_valid_range).is_true()

	# Combat should have occurred
	assert_bool(_combat_occurred).is_true()


func _create_character(p_name: String, hp: int, mp: int, str_val: int, def_val: int, agi: int) -> CharacterData:
	var character: CharacterData = CharacterFactory.create_combatant(p_name, hp, mp, str_val, def_val, agi)
	character.character_class.movement_range = 5
	_created_characters.append(character)
	return character


func _create_archer_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_ranged("test_opportunistic_archer")
	_created_behaviors.append(behavior)
	return behavior


func _spawn_unit(character: CharacterData, cell: Vector2i, p_faction: String, p_ai_behavior: AIBehaviorData) -> Unit:
	return UnitFactory.spawn_unit(character, cell, p_faction, _units_container, p_ai_behavior)


func _get_distance(unit_a: Unit, unit_b: Unit) -> int:
	return GridManager.grid.get_manhattan_distance(unit_a.grid_position, unit_b.grid_position)


func _execute_archer_turn() -> void:
	var context: Dictionary = {
		"player_units": BattleManager.player_units,
		"enemy_units": BattleManager.enemy_units,
		"neutral_units": [],
		"turn_number": 1,
		"ai_delays": {"after_movement": 0.0, "before_attack": 0.0}
	}

	var ConfigurableAIBrainScript: GDScript = load("res://core/systems/ai/configurable_ai_brain.gd")
	var brain: AIBrain = ConfigurableAIBrainScript.get_instance()
	await brain.execute_with_behavior(_archer_unit, context, _archer_unit.ai_behavior)

	# Wait for movement to complete (with timeout)
	# Wait for movement to complete with bounded delay
	await await_millis(100)
	if _archer_unit.is_moving():
		await await_millis(500)


func _on_combat_resolved(attacker: Unit, _defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	if attacker == _archer_unit:
		_combat_occurred = true
		_archer_final_pos = _archer_unit.grid_position


func _cleanup_units() -> void:
	UnitFactory.cleanup_unit(_archer_unit)
	_archer_unit = null
	UnitFactory.cleanup_unit(_target_unit)
	_target_unit = null


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
	_created_items.clear()
