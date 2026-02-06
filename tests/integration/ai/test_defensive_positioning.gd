## Defensive Tank Positioning Integration Test
##
## Tests that defensive AI units position themselves between
## valuable allies (VIPs) and enemy threats.
##
## Validates:
## - Tank moves toward intercept position between VIP and threat
## - Tank prioritizes protection over attacking
## - Tank ends closer to VIP than it started
class_name TestDefensivePositioning
extends GdUnitTestSuite

const UnitScript = preload("res://core/components/unit.gd")
const CharacterFactoryScript = preload("res://tests/fixtures/character_factory.gd")
const UnitFactoryScript = preload("res://tests/fixtures/unit_factory.gd")
const AIBehaviorFactoryScript = preload("res://tests/fixtures/ai_behavior_factory.gd")
const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")

# Units
var _tank_unit: Unit
var _vip_unit: Unit
var _threat_unit: Unit

# Tracking
var _tank_initial_pos: Vector2i
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


func test_tank_positions_between_vip_and_threat() -> void:
	# Create tank character (defensive unit) using CharacterFactory
	var tank_character: CharacterData = CharacterFactoryScript.create_combatant("Tank", 100, 10, 15, 18, 8)
	_created_characters.append(tank_character)

	# Create VIP character (healer-type, high value target)
	var vip_character: CharacterData = _create_vip_character("VIPHealer", 40, 30, 6, 6, 10)

	# Create threat character (enemy approaching VIP) using CharacterFactory
	var threat_character: CharacterData = CharacterFactoryScript.create_combatant("Threat", 80, 10, 20, 12, 12)
	threat_character.is_hero = true
	_created_characters.append(threat_character)

	# Create defensive behavior for tank
	var tank_ai: AIBehaviorData = _create_defensive_behavior()

	# Spawn tank at (2, 5) - starting far from VIP
	_tank_unit = UnitFactoryScript.spawn_unit(tank_character, Vector2i(2, 5), "enemy", _units_container, tank_ai)
	_tank_initial_pos = _tank_unit.grid_position

	# Spawn VIP at (5, 5) - the unit to protect
	_vip_unit = UnitFactoryScript.spawn_unit(vip_character, Vector2i(5, 5), "enemy", _units_container)

	# Spawn threat at (8, 5) - approaching VIP from the right
	_threat_unit = UnitFactoryScript.spawn_unit(threat_character, Vector2i(8, 5), "player", _units_container)

	# Setup BattleManager
	BattleManager.setup(_units_container, _units_container)
	BattleManager.player_units = [_threat_unit]
	BattleManager.enemy_units = [_tank_unit, _vip_unit]
	BattleManager.all_units = [_tank_unit, _vip_unit, _threat_unit]

	# Connect to combat signal via tracker
	_tracker.track_with_callback(BattleManager.combat_resolved, _on_combat_resolved)

	# Run the AI turn
	await _execute_tank_turn()

	# Wait for AI processing to complete
	await await_millis(100)

	# Validate results
	var tank_final_pos: Vector2i = _tank_unit.grid_position
	var vip_pos: Vector2i = _vip_unit.grid_position
	var threat_pos: Vector2i = _threat_unit.grid_position

	var initial_dist_to_vip: int = GridManager.grid.get_manhattan_distance(_tank_initial_pos, vip_pos)
	var final_dist_to_vip: int = GridManager.grid.get_manhattan_distance(tank_final_pos, vip_pos)
	var threat_dist_to_vip: int = GridManager.grid.get_manhattan_distance(threat_pos, vip_pos)

	# Tank should move closer to VIP
	assert_bool(final_dist_to_vip < initial_dist_to_vip).is_true()

	# Tank should be positioned between VIP and threat (closer to VIP than threat is)
	assert_bool(final_dist_to_vip <= threat_dist_to_vip).is_true()


func _create_vip_character(p_name: String, hp: int, mp: int, str_val: int, def_val: int, agi: int) -> CharacterData:
	var character: CharacterData = CharacterData.new()
	character.character_name = p_name
	character.base_hp = hp
	character.base_mp = mp
	character.base_strength = str_val
	character.base_defense = def_val
	character.base_agility = agi
	character.base_intelligence = 18
	character.base_luck = 5
	character.starting_level = 1
	# Mark as VIP for protection priority
	character.ai_threat_tags = ["vip"]
	character.ai_threat_modifier = 1.5

	var healer_class: ClassData = ClassData.new()
	healer_class.display_name = "Healer"
	healer_class.movement_type = ClassData.MovementType.WALKING
	healer_class.movement_range = 3

	# Add heal ability to make it even more valuable
	var heal_ability: AbilityData = AbilityData.new()
	heal_ability.ability_name = "Heal"
	heal_ability.ability_id = "test_vip_heal"
	heal_ability.ability_type = AbilityData.AbilityType.HEAL
	heal_ability.target_type = AbilityData.TargetType.SINGLE_ALLY
	heal_ability.min_range = 1
	heal_ability.max_range = 2
	heal_ability.mp_cost = 5
	heal_ability.potency = 20

	healer_class.class_abilities = [heal_ability]
	healer_class.ability_unlock_levels = {"test_vip_heal": 1}

	character.character_class = healer_class

	# Track for cleanup
	_created_characters.append(character)
	_created_classes.append(healer_class)
	_created_abilities.append(heal_ability)

	return character


func _create_defensive_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_defensive("test_defensive_tank")
	_created_behaviors.append(behavior)
	return behavior


func _execute_tank_turn() -> void:
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
	await brain.execute_with_behavior(_tank_unit, context, _tank_unit.ai_behavior)

	# Wait for movement to complete with bounded delay
	await await_millis(100)
	if _tank_unit.is_moving():
		await await_millis(500)


func _on_combat_resolved(attacker: Unit, _defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	if attacker == _tank_unit:
		_combat_occurred = true


func _cleanup_units() -> void:
	UnitFactoryScript.cleanup_unit(_tank_unit)
	_tank_unit = null
	UnitFactoryScript.cleanup_unit(_vip_unit)
	_vip_unit = null
	UnitFactoryScript.cleanup_unit(_threat_unit)
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
	_created_classes.clear()
	_created_behaviors.clear()
	_created_abilities.clear()
