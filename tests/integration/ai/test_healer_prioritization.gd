## Healer Prioritization Integration Test (Dark Priest Problem)
##
## Tests that support role units prioritize healing wounded allies
## over attacking enemies, even when enemies are in attack range.
##
## Validates:
## - Healer with wounded ally and enemy in range heals first
## - Healer does NOT attack when healing is needed
## - Support role behavior matches its intent
class_name TestHealerPrioritization
extends GdUnitTestSuite

const UnitScript = preload("res://core/components/unit.gd")
const CharacterFactoryScript = preload("res://tests/fixtures/character_factory.gd")
const UnitFactoryScript = preload("res://tests/fixtures/unit_factory.gd")
const AIBehaviorFactoryScript = preload("res://tests/fixtures/ai_behavior_factory.gd")
const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")

# Units
var _healer_unit: Unit
var _wounded_ally: Unit
var _enemy_unit: Unit

# Tracking
var _healer_attacked: bool = false
var _ally_initial_hp: int = 0
var _healer_initial_mp: int = 0
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
var _created_abilities: Array[AbilityData] = []


func before() -> void:
	_healer_attacked = false
	_tracker = SignalTrackerScript.new()

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


func test_healer_prioritizes_healing_over_attacking() -> void:
	# Create healer character with healing ability
	var healer_character: CharacterData = _create_healer_character("TestHealer")

	# Create wounded ally character using CharacterFactory
	var ally_character: CharacterData = CharacterFactoryScript.create_combatant("WoundedAlly", 100, 10, 10, 10, 10)
	_created_characters.append(ally_character)

	# Create enemy character using CharacterFactory
	var enemy_character: CharacterData = CharacterFactoryScript.create_combatant("TestEnemy", 50, 10, 10, 10, 5)
	enemy_character.is_hero = true
	_created_characters.append(enemy_character)

	# Create support role AI behavior
	var healer_ai: AIBehaviorData = _create_support_behavior()

	# Spawn healer at (5, 5)
	_healer_unit = UnitFactoryScript.spawn_unit(healer_character, Vector2i(5, 5), "enemy", _units_container, healer_ai)

	# Spawn wounded ally at (6, 5) - adjacent to healer, 30% HP
	_wounded_ally = UnitFactoryScript.spawn_unit(ally_character, Vector2i(6, 5), "enemy", _units_container)
	_wounded_ally.stats.current_hp = 30
	_ally_initial_hp = _wounded_ally.stats.current_hp

	# Spawn enemy at (4, 5) - adjacent to healer on other side (in attack range)
	_enemy_unit = UnitFactoryScript.spawn_unit(enemy_character, Vector2i(4, 5), "player", _units_container)

	# Record initial state
	_healer_initial_mp = _healer_unit.stats.current_mp

	# Setup BattleManager
	BattleManager.setup(_units_container, _units_container)
	BattleManager.player_units = [_enemy_unit]
	BattleManager.enemy_units = [_healer_unit, _wounded_ally]
	BattleManager.all_units = [_healer_unit, _wounded_ally, _enemy_unit]

	# Connect combat signal via tracker
	_tracker.track_with_callback(BattleManager.combat_resolved, _on_combat_resolved)

	# Run the AI turn
	await _execute_healer_turn()

	# Wait for AI processing to complete
	await await_millis(100)

	# Check if ally was healed
	var ally_hp_change: int = _wounded_ally.stats.current_hp - _ally_initial_hp
	var healer_mp_change: int = _healer_initial_mp - _healer_unit.stats.current_mp
	var healing_occurred: bool = ally_hp_change > 0 or healer_mp_change > 0

	# Healer should NOT attack
	assert_bool(_healer_attacked).is_false()

	# Healer should heal the wounded ally
	assert_bool(healing_occurred).is_true()


func _create_healer_character(p_name: String) -> CharacterData:
	var character: CharacterData = CharacterData.new()
	character.character_name = p_name
	character.base_hp = 40
	character.base_mp = 30
	character.base_strength = 5
	character.base_defense = 8
	character.base_agility = 10
	character.base_intelligence = 15
	character.base_luck = 5
	character.starting_level = 1

	# Create healer class with healing ability
	var healer_class: ClassData = ClassData.new()
	healer_class.display_name = "Priest"
	healer_class.movement_type = ClassData.MovementType.WALKING
	healer_class.movement_range = 4

	# Create healing ability
	var heal_ability: AbilityData = AbilityData.new()
	heal_ability.ability_name = "Heal"
	heal_ability.ability_id = "test_heal"
	heal_ability.ability_type = AbilityData.AbilityType.HEAL
	heal_ability.target_type = AbilityData.TargetType.SINGLE_ALLY
	heal_ability.min_range = 1
	heal_ability.max_range = 2
	heal_ability.mp_cost = 5
	heal_ability.potency = 20

	# Add ability to class
	healer_class.class_abilities = [heal_ability]
	healer_class.ability_unlock_levels = {"test_heal": 1}

	# Register in ModLoader so execute_ai_spell can look it up
	if ModLoader and ModLoader.registry:
		ModLoader.registry.register_resource(heal_ability, "ability", "test_heal", "_test")

	character.character_class = healer_class

	# Track for cleanup
	_created_characters.append(character)
	_created_classes.append(healer_class)
	_created_abilities.append(heal_ability)

	return character


func _create_support_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_support("test_support")
	_created_behaviors.append(behavior)
	return behavior


func _execute_healer_turn() -> void:
	var context: Dictionary = {
		"player_units": BattleManager.player_units,
		"enemy_units": BattleManager.enemy_units,
		"neutral_units": [],
		"turn_number": 1,
		"ai_delays": {"after_movement": 0.0, "before_attack": 0.0}
	}

	var ConfigurableAIBrainScript: GDScript = load("res://core/systems/ai/configurable_ai_brain.gd")
	var brain: AIBrain = ConfigurableAIBrainScript.get_instance()
	await brain.execute_with_behavior(_healer_unit, context, _healer_unit.ai_behavior)

	# Wait for any async operations (with timeout)
	# Wait for movement to complete with bounded delay
	await await_millis(100)
	if _healer_unit.is_moving():
		await await_millis(500)


func _on_combat_resolved(attacker: Unit, _defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	if attacker == _healer_unit:
		_healer_attacked = true


func _cleanup_units() -> void:
	UnitFactoryScript.cleanup_unit(_healer_unit)
	_healer_unit = null
	UnitFactoryScript.cleanup_unit(_wounded_ally)
	_wounded_ally = null
	UnitFactoryScript.cleanup_unit(_enemy_unit)
	_enemy_unit = null


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
	_created_abilities.clear()
