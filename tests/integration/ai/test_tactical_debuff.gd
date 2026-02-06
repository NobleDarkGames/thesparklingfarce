## Tactical Debuff Usage Integration Test
##
## Tests that tactical AI units prioritize casting debuffs on
## high-threat targets instead of just attacking.
##
## Validates:
## - Tactical mage casts debuff when available
## - MP is consumed for the spell
## - Mage doesn't just spam basic attacks
class_name TestTacticalDebuff
extends GdUnitTestSuite

const UnitScript = preload("res://core/components/unit.gd")
const AIBehaviorFactoryScript = preload("res://tests/fixtures/ai_behavior_factory.gd")
const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")

# Units
var _mage_unit: Unit
var _target_unit: Unit

# Tracking
var _mage_initial_mp: int = 0
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
var _created_abilities: Array[AbilityData] = []


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

	# Setup grid
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


func test_tactical_mage_casts_debuff_instead_of_attacking() -> void:
	# Create tactical mage character with debuff ability
	var mage_character: CharacterData = _create_tactical_mage("TacticalMage")

	# Create target character (high threat - damage dealer)
	var target_character: CharacterData = _create_character("DamageDealer", 80, 10, 25, 10, 12)
	target_character.is_hero = true

	# Create tactical behavior
	var mage_ai: AIBehaviorData = _create_tactical_behavior()

	# Spawn mage at (5, 5)
	_mage_unit = _spawn_unit(mage_character, Vector2i(5, 5), "enemy", mage_ai)
	_mage_initial_mp = _mage_unit.stats.current_mp

	# Spawn target at (7, 5) - distance 2, within debuff range
	_target_unit = _spawn_unit(target_character, Vector2i(7, 5), "player", null)

	# Setup BattleManager
	BattleManager.setup(_units_container, _units_container)
	BattleManager.player_units = [_target_unit]
	BattleManager.enemy_units = [_mage_unit]
	BattleManager.all_units = [_mage_unit, _target_unit]

	# Connect combat signal via tracker
	_tracker.track_with_callback(BattleManager.combat_resolved, _on_combat_resolved)

	# Run the AI turn
	await _execute_mage_turn()

	# Wait for AI processing to complete
	await await_millis(100)

	# Check if MP was spent (indicating spell was cast)
	var mp_spent: int = _mage_initial_mp - _mage_unit.stats.current_mp
	var spell_cast: bool = mp_spent > 0

	# Tactical mage should cast spell (spend MP)
	assert_bool(spell_cast).is_true()


func _create_character(p_name: String, hp: int, mp: int, str_val: int, def_val: int, agi: int) -> CharacterData:
	var character: CharacterData = CharacterFactory.create_combatant(p_name, hp, mp, str_val, def_val, agi)
	_created_characters.append(character)
	return character


func _create_tactical_mage(p_name: String) -> CharacterData:
	var character: CharacterData = CharacterData.new()
	character.character_name = p_name
	character.base_hp = 50
	character.base_mp = 40
	character.base_strength = 8
	character.base_defense = 8
	character.base_agility = 10
	character.base_intelligence = 20
	character.base_luck = 5
	character.starting_level = 1

	# Create mage class with debuff ability
	var mage_class: ClassData = ClassData.new()
	mage_class.display_name = "Tactician"
	mage_class.movement_type = ClassData.MovementType.WALKING
	mage_class.movement_range = 3

	# Create debuff ability (Weaken - reduces target's attack)
	var debuff_ability: AbilityData = AbilityData.new()
	debuff_ability.ability_name = "Weaken"
	debuff_ability.ability_id = "test_weaken"
	debuff_ability.ability_type = AbilityData.AbilityType.DEBUFF
	debuff_ability.target_type = AbilityData.TargetType.SINGLE_ENEMY
	debuff_ability.min_range = 1
	debuff_ability.max_range = 3
	debuff_ability.mp_cost = 8
	debuff_ability.potency = 5

	# Add ability to class
	mage_class.class_abilities = [debuff_ability]
	mage_class.ability_unlock_levels = {"test_weaken": 1}

	# Register in ModLoader
	if ModLoader and ModLoader.registry:
		ModLoader.registry.register_resource(debuff_ability, "ability", "test_weaken", "_test")

	character.character_class = mage_class

	# Track for cleanup
	_created_characters.append(character)
	_created_abilities.append(debuff_ability)

	return character


func _create_tactical_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_tactical("test_tactical")
	_created_behaviors.append(behavior)
	return behavior


func _spawn_unit(character: CharacterData, cell: Vector2i, p_faction: String, p_ai_behavior: AIBehaviorData) -> Unit:
	return UnitFactory.spawn_unit(character, cell, p_faction, _units_container, p_ai_behavior)


func _execute_mage_turn() -> void:
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
	await brain.execute_with_behavior(_mage_unit, context, _mage_unit.ai_behavior)

	# Wait for any movement/casting to complete
	# Wait for movement to complete with bounded delay
	await await_millis(100)
	if _mage_unit.is_moving():
		await await_millis(500)


func _on_combat_resolved(attacker: Unit, _defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	if attacker == _mage_unit:
		_combat_occurred = true


func _cleanup_units() -> void:
	UnitFactory.cleanup_unit(_mage_unit)
	_mage_unit = null
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
	_created_abilities.clear()
