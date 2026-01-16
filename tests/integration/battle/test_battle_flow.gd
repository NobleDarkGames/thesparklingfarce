## Battle Flow Integration Test
##
## Tests the complete battle flow from start to victory.
## Uses controlled combat to ensure predictable outcomes.
##
## Validates:
## - Battle initialization and setup
## - Turn order calculation
## - Combat execution and damage application
## - Victory condition triggering
## - All relevant signals firing correctly
class_name TestBattleFlow
extends GdUnitTestSuite

const UnitScript = preload("res://core/components/unit.gd")
const GridSetupScript = preload("res://tests/fixtures/grid_setup.gd")
const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")

# Scene container (GdUnitTestSuite extends Node, we need Node2D for some operations)
var _container: Node2D
var _grid_setup: GridSetup

# Signal tracking
var _tracker: SignalTracker

# Units
var _player_unit: Unit
var _enemy_unit: Unit

# Event tracking for validation
var _events_recorded: Array[String] = []
var _battle_result: bool = false
var _battle_complete: bool = false

# Resources to clean up (behaviors still tracked for RefCounted cleanup)
var _created_behaviors: Array[AIBehaviorData] = []


func before() -> void:
	_events_recorded.clear()
	_battle_result = false
	_battle_complete = false

	# Create container for scene tree operations
	_container = Node2D.new()
	add_child(_container)

	# Setup grid using fixture
	_grid_setup = GridSetupScript.new()
	_grid_setup.create_grid(_container, Vector2i(10, 10))

	# Initialize signal tracker and connect signals with callbacks
	_tracker = SignalTrackerScript.new()
	_tracker.track_with_callback(TurnManager.enemy_turn_started, _on_enemy_turn_started)
	_tracker.track_with_callback(TurnManager.player_turn_started, _on_player_turn_started)
	_tracker.track_with_callback(TurnManager.battle_ended, _on_battle_ended)
	_tracker.track_with_callback(BattleManager.combat_resolved, _on_combat_resolved)

	await await_millis(100)


func after() -> void:
	# Disconnect all tracked signals
	if _tracker:
		_tracker.disconnect_all()
		_tracker = null

	# Cleanup units
	_cleanup_units()

	# Clean up grid
	_grid_setup.cleanup()
	_grid_setup = null

	# Clean up container
	if _container and is_instance_valid(_container):
		_container.queue_free()
		_container = null

	# Clean up resources
	_created_behaviors.clear()


func test_battle_flow_start_to_victory() -> void:
	# Create test characters
	# Hero: Very strong to guarantee quick victory (high STR, high DEF)
	var player_character: CharacterData = CharacterFactory.create_combatant("TestHero", 50, 10, 30, 20, 15)
	player_character.is_hero = true  # Required for TurnManager battle end detection
	# Goblin: Weak enemy that will die quickly (low HP, low DEF)
	var enemy_character: CharacterData = CharacterFactory.create_combatant("TestGoblin", 10, 5, 5, 2, 5)

	# Create aggressive AI behavior inline for test isolation
	var aggressive_ai: AIBehaviorData = _create_aggressive_behavior()

	# Both units use aggressive behavior - will attack immediately
	var player_ai: AIBehaviorData = aggressive_ai

	# Spawn units adjacent so combat can happen immediately
	_player_unit = UnitFactory.spawn_unit(player_character, Vector2i(3, 5), "player", _container, player_ai)
	_enemy_unit = UnitFactory.spawn_unit(enemy_character, Vector2i(4, 5), "enemy", _container, aggressive_ai)

	# Setup BattleManager
	BattleManager.setup(_container, _container)
	BattleManager.player_units = [_player_unit]
	BattleManager.enemy_units = [_enemy_unit]
	BattleManager.all_units = [_player_unit, _enemy_unit]

	# Record battle start event
	_record_event("battle_started")

	# Start battle
	var all_units: Array[Unit] = [_player_unit, _enemy_unit]
	TurnManager.start_battle(all_units)

	# Wait for battle to complete (with timeout)
	var wait_start: float = Time.get_ticks_msec()
	var max_wait_ms: float = 10000  # 10 second timeout
	while not _battle_complete and (Time.get_ticks_msec() - wait_start) < max_wait_ms:
		await get_tree().process_frame

	# Verify expected events occurred
	assert_bool("battle_started" in _events_recorded).is_true()
	assert_bool("turn_started" in _events_recorded).is_true()
	assert_bool("combat_occurred" in _events_recorded).is_true()
	assert_bool("battle_victory" in _events_recorded).is_true()


func _create_aggressive_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = "test_aggressive_melee"
	behavior.display_name = "Test Aggressive"
	behavior.role = "aggressive"
	behavior.behavior_mode = "aggressive"
	behavior.retreat_enabled = false

	# Track for cleanup
	_created_behaviors.append(behavior)

	return behavior


func _record_event(event_name: String) -> void:
	_events_recorded.append(event_name)


func _on_player_turn_started(unit: Unit) -> void:
	_record_event("turn_started")

	# For integration testing: manually invoke the AI for player units
	# TurnManager doesn't auto-invoke AI for player faction
	if unit.ai_behavior:
		# Swap player/enemy in context so AI targets enemies, not allies
		var context: Dictionary = {
			"player_units": BattleManager.enemy_units,
			"enemy_units": BattleManager.player_units,
			"neutral_units": BattleManager.neutral_units,
			"turn_number": TurnManager.turn_number,
			"ai_delays": {"after_movement": 0.0, "before_attack": 0.0}
		}

		# Use ConfigurableAIBrain to interpret the behavior data
		var ConfigurableAIBrainScript: GDScript = load("res://core/systems/ai/configurable_ai_brain.gd")
		var brain: AIBrain = ConfigurableAIBrainScript.get_instance()
		await brain.execute_with_behavior(unit, context, unit.ai_behavior)

		# End turn if not already ended by combat
		if TurnManager.active_unit == unit:
			TurnManager.end_unit_turn(unit)
	else:
		await await_millis(100)
		TurnManager.end_unit_turn(unit)


func _on_enemy_turn_started(_unit: Unit) -> void:
	_record_event("turn_started")


func _on_combat_resolved(_attacker: Unit, _defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	_record_event("combat_occurred")


func _on_battle_ended(victory: bool) -> void:
	if victory:
		_record_event("battle_victory")
	else:
		_record_event("battle_defeat")

	_battle_result = victory
	_battle_complete = true


func _cleanup_units() -> void:
	UnitFactory.cleanup_unit(_player_unit)
	_player_unit = null
	UnitFactory.cleanup_unit(_enemy_unit)
	_enemy_unit = null
