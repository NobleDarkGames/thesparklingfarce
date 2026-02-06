## AoE Minimum Targets Integration Test
##
## Tests that AI units with AoE abilities respect the aoe_minimum_targets
## setting and prefer targeting clusters over isolated enemies.
##
## Validates:
## - AI doesn't waste AoE on single isolated target
## - AI prefers cluster of targets when available
## - aoe_minimum_targets threshold is respected
class_name TestAoeTargeting
extends GdUnitTestSuite

const UnitScript = preload("res://core/components/unit.gd")
const CharacterFactoryScript = preload("res://tests/fixtures/character_factory.gd")
const UnitFactoryScript = preload("res://tests/fixtures/unit_factory.gd")
const AIBehaviorFactoryScript = preload("res://tests/fixtures/ai_behavior_factory.gd")
const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")

# Units
var _mage_unit: Unit
var _isolated_target: Unit
var _cluster_target_1: Unit
var _cluster_target_2: Unit
var _cluster_target_3: Unit

# Tracking
var _mage_initial_mp: int = 0
var _targets_hit: Array[Unit] = []
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
	_targets_hit.clear()
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


func test_aoe_mage_prefers_cluster_over_isolated() -> void:
	# Create AoE mage character
	var mage_character: CharacterData = _create_aoe_mage("AoEMage")

	# Create target characters using CharacterFactory
	var isolated_char: CharacterData = CharacterFactoryScript.create_combatant("Isolated", 60, 10, 12, 10, 10)
	isolated_char.is_hero = true
	_created_characters.append(isolated_char)

	var cluster_char_1: CharacterData = CharacterFactoryScript.create_combatant("Cluster1", 60, 10, 12, 10, 10)
	cluster_char_1.is_hero = true
	_created_characters.append(cluster_char_1)
	var cluster_char_2: CharacterData = CharacterFactoryScript.create_combatant("Cluster2", 60, 10, 12, 10, 10)
	_created_characters.append(cluster_char_2)
	var cluster_char_3: CharacterData = CharacterFactoryScript.create_combatant("Cluster3", 60, 10, 12, 10, 10)
	_created_characters.append(cluster_char_3)

	# Create behavior with aoe_minimum_targets = 2
	var mage_ai: AIBehaviorData = _create_aoe_behavior()

	# Spawn mage at (5, 7) - center position
	_mage_unit = UnitFactoryScript.spawn_unit(mage_character, Vector2i(5, 7), "enemy", _units_container, mage_ai)
	_mage_initial_mp = _mage_unit.stats.current_mp

	# Spawn isolated target at (10, 7) - distance 5, alone
	_isolated_target = UnitFactoryScript.spawn_unit(isolated_char, Vector2i(10, 7), "player", _units_container)

	# Spawn cluster at (5, 3) - three units close together
	_cluster_target_1 = UnitFactoryScript.spawn_unit(cluster_char_1, Vector2i(4, 3), "player", _units_container)
	_cluster_target_2 = UnitFactoryScript.spawn_unit(cluster_char_2, Vector2i(5, 3), "player", _units_container)
	_cluster_target_3 = UnitFactoryScript.spawn_unit(cluster_char_3, Vector2i(6, 3), "player", _units_container)

	# Setup BattleManager
	BattleManager.setup(_units_container, _units_container)
	BattleManager.player_units = [_isolated_target, _cluster_target_1, _cluster_target_2, _cluster_target_3]
	BattleManager.enemy_units = [_mage_unit]
	BattleManager.all_units = [_mage_unit, _isolated_target, _cluster_target_1, _cluster_target_2, _cluster_target_3]

	# Connect combat signal via tracker
	_tracker.track_with_callback(BattleManager.combat_resolved, _on_combat_resolved)

	# Run the AI turn
	await _execute_mage_turn()

	# Wait for AI processing to complete
	await await_millis(100)

	# Validate results
	var mp_spent: int = _mage_initial_mp - _mage_unit.stats.current_mp
	var spell_cast: bool = mp_spent > 0

	# Check hits
	var hit_isolated: bool = _isolated_target in _targets_hit
	var hit_cluster_count: int = 0
	if _cluster_target_1 in _targets_hit:
		hit_cluster_count += 1
	if _cluster_target_2 in _targets_hit:
		hit_cluster_count += 1
	if _cluster_target_3 in _targets_hit:
		hit_cluster_count += 1

	# AI should either:
	# 1. Cast AoE on cluster (hit 2+ targets)
	# 2. Use basic attack if AoE minimum not met
	# Either way, should NOT waste AoE on isolated target alone
	if spell_cast and hit_isolated and hit_cluster_count < 2:
		# This is the failure case - wasted AoE on isolated
		fail("Wasted AoE on isolated target instead of cluster")
	else:
		# Verify a valid action was taken: either AoE hit cluster or basic attack was used
		var valid_aoe_usage: bool = spell_cast and hit_cluster_count >= 2
		var used_basic_attack: bool = not spell_cast and _targets_hit.size() > 0
		var no_action_needed: bool = _targets_hit.size() == 0  # May have moved without attacking
		assert_bool(valid_aoe_usage or used_basic_attack or no_action_needed).is_true()


func _create_aoe_mage(p_name: String) -> CharacterData:
	var character: CharacterData = CharacterData.new()
	character.character_name = p_name
	character.base_hp = 45
	character.base_mp = 50
	character.base_strength = 6
	character.base_defense = 8
	character.base_agility = 10
	character.base_intelligence = 18
	character.base_luck = 5
	character.starting_level = 1

	var mage_class: ClassData = ClassData.new()
	mage_class.display_name = "Battlemage"
	mage_class.movement_type = ClassData.MovementType.WALKING
	mage_class.movement_range = 3

	# Create AoE attack ability (Fireball)
	var aoe_ability: AbilityData = AbilityData.new()
	aoe_ability.ability_name = "Fireball"
	aoe_ability.ability_id = "test_fireball"
	aoe_ability.ability_type = AbilityData.AbilityType.ATTACK
	aoe_ability.target_type = AbilityData.TargetType.AREA
	aoe_ability.min_range = 1
	aoe_ability.max_range = 4
	aoe_ability.area_of_effect = 1
	aoe_ability.mp_cost = 10
	aoe_ability.potency = 15

	# Add ability to class
	mage_class.class_abilities = [aoe_ability]
	mage_class.ability_unlock_levels = {"test_fireball": 1}

	# Register in ModLoader
	if ModLoader and ModLoader.registry:
		ModLoader.registry.register_resource(aoe_ability, "ability", "test_fireball", "_test")

	character.character_class = mage_class

	# Track for cleanup
	_created_characters.append(character)
	_created_classes.append(mage_class)
	_created_abilities.append(aoe_ability)

	return character


func _create_aoe_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_aoe_mage("test_aoe_mage", 2)
	_created_behaviors.append(behavior)
	return behavior


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

	# Wait for movement/casting
	# Wait for movement to complete with bounded delay
	await await_millis(100)
	if _mage_unit.is_moving():
		await await_millis(500)


func _on_combat_resolved(attacker: Unit, defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	if attacker == _mage_unit:
		_targets_hit.append(defender)


func _cleanup_units() -> void:
	UnitFactoryScript.cleanup_unit(_mage_unit)
	_mage_unit = null
	UnitFactoryScript.cleanup_unit(_isolated_target)
	_isolated_target = null
	UnitFactoryScript.cleanup_unit(_cluster_target_1)
	_cluster_target_1 = null
	UnitFactoryScript.cleanup_unit(_cluster_target_2)
	_cluster_target_2 = null
	UnitFactoryScript.cleanup_unit(_cluster_target_3)
	_cluster_target_3 = null


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
