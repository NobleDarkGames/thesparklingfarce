## Opportunistic Target Selection Integration Test
##
## Tests that opportunistic AI units prioritize wounded targets over
## closer full-HP targets, enabling "finishing blow" behavior.
##
## Validates:
## - Attacker ignores closer full-HP target
## - Attacker moves toward and attacks wounded target
## - Wounded priority weight functions correctly
class_name TestOpportunisticTargeting
extends GdUnitTestSuite

const UnitScript = preload("res://core/components/unit.gd")
const CharacterFactoryScript = preload("res://tests/fixtures/character_factory.gd")
const UnitFactoryScript = preload("res://tests/fixtures/unit_factory.gd")

# Units
var _attacker_unit: Unit
var _full_hp_target: Unit
var _wounded_target: Unit

# Tracking
var _attacker_start_pos: Vector2i
var _attacked_target: Unit = null
var _combat_occurred: bool = false

# Scene container for units (BattleManager needs Node2D)
var _units_container: Node2D

# Resources to clean up
var _tilemap_layer: TileMapLayer
var _tileset: TileSet
var _grid_resource: Grid
var _created_characters: Array[CharacterData] = []
var _created_classes: Array[ClassData] = []
var _created_behaviors: Array[AIBehaviorData] = []


func before() -> void:
	_combat_occurred = false
	_attacked_target = null

	# Create units container (BattleManager needs Node2D)
	_units_container = Node2D.new()
	add_child(_units_container)

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


func after() -> void:
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


func test_attacker_prioritizes_wounded_over_closer_target() -> void:
	# Create attacker character using CharacterFactory
	var attacker_character: CharacterData = CharacterFactoryScript.create_combatant("Opportunist", 80, 10, 20, 12, 14)
	_created_characters.append(attacker_character)
	# Set movement range to 5 as the original test used
	attacker_character.character_class.movement_range = 5

	# Create full HP target character using CharacterFactory
	var full_hp_character: CharacterData = CharacterFactoryScript.create_combatant("FullHPTarget", 100, 10, 15, 15, 10)
	full_hp_character.is_hero = true
	_created_characters.append(full_hp_character)

	# Create wounded target character using CharacterFactory
	var wounded_character: CharacterData = CharacterFactoryScript.create_combatant("WoundedTarget", 100, 10, 15, 15, 10)
	wounded_character.is_hero = true
	_created_characters.append(wounded_character)

	# Create opportunistic behavior
	var attacker_ai: AIBehaviorData = _create_opportunistic_behavior()

	# Spawn attacker at (2, 5)
	_attacker_start_pos = Vector2i(2, 5)
	_attacker_unit = UnitFactoryScript.spawn_unit(attacker_character, _attacker_start_pos, "enemy", _units_container, attacker_ai)

	# Spawn full HP target at (4, 5) - distance 2 (closer)
	_full_hp_target = UnitFactoryScript.spawn_unit(full_hp_character, Vector2i(4, 5), "player", _units_container)

	# Spawn wounded target at (6, 5) - distance 4 (farther but wounded)
	_wounded_target = UnitFactoryScript.spawn_unit(wounded_character, Vector2i(6, 5), "player", _units_container)
	_wounded_target.stats.current_hp = 20  # 20% HP

	# Setup BattleManager
	BattleManager.setup(_units_container, _units_container)
	BattleManager.player_units = [_full_hp_target, _wounded_target]
	BattleManager.enemy_units = [_attacker_unit]
	BattleManager.all_units = [_attacker_unit, _full_hp_target, _wounded_target]

	# Connect to combat signal
	BattleManager.combat_resolved.connect(_on_combat_resolved)

	# Run the AI turn
	await _execute_attacker_turn()

	# Wait for processing
	await await_millis(100)

	# Combat should occur
	assert_bool(_combat_occurred).is_true()

	# Attacker should prioritize wounded target over closer full-HP target
	assert_object(_attacked_target).is_same(_wounded_target)


func _create_opportunistic_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = "test_opportunistic"
	behavior.display_name = "Test Opportunistic"
	behavior.role = "aggressive"
	behavior.behavior_mode = "opportunistic"
	behavior.retreat_enabled = false
	behavior.use_healing_items = false
	behavior.use_attack_items = false
	behavior.threat_weights = {
		"wounded_target": 2.0,
		"proximity": 0.3
	}

	# Track for cleanup
	_created_behaviors.append(behavior)

	return behavior


func _execute_attacker_turn() -> void:
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
	await brain.execute_with_behavior(_attacker_unit, context, _attacker_unit.ai_behavior)

	# Wait for movement to complete (with timeout)
	var wait_start: float = Time.get_ticks_msec()
	while _attacker_unit.is_moving() and (Time.get_ticks_msec() - wait_start) < 3000:
		await get_tree().process_frame


func _on_combat_resolved(attacker: Unit, defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	if attacker == _attacker_unit:
		_combat_occurred = true
		_attacked_target = defender


func _cleanup_units() -> void:
	UnitFactoryScript.cleanup_unit(_attacker_unit)
	_attacker_unit = null
	UnitFactoryScript.cleanup_unit(_full_hp_target)
	_full_hp_target = null
	UnitFactoryScript.cleanup_unit(_wounded_target)
	_wounded_target = null


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
