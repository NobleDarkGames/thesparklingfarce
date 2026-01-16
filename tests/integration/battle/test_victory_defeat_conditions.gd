## Unit Tests for Victory and Defeat Conditions in TurnManager
##
## Tests the victory/defeat condition checking logic including:
## - DEFEAT_ALL_ENEMIES, DEFEAT_BOSS, SURVIVE_TURNS victory conditions
## - ALL_UNITS_DEFEATED, LEADER_DEFEATED, TURN_LIMIT defeat conditions
## - Mod hooks for overriding conditions via signals
##
## These are unit tests using mock objects to avoid full scene setup.
class_name TestVictoryDefeatConditions
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES - Mock Objects
# =============================================================================

## Mock unit for testing (simulates a battlefield unit)
## Extends Unit to satisfy type requirements but bypasses scene structure
class MockUnit extends Unit:
	var _mock_is_alive: bool = true

	func _ready() -> void:
		# Override to prevent parent from accessing missing child nodes
		pass

	func is_alive() -> bool:
		return _mock_is_alive

	func is_dead() -> bool:
		return not _mock_is_alive

	func set_hero(val: bool) -> void:
		if character_data == null:
			character_data = MockCharacterData.new()
		character_data.is_hero = val

	func set_boss(val: bool) -> void:
		if character_data == null:
			character_data = MockCharacterData.new()
		character_data.is_boss = val


## Mock CharacterData for testing
class MockCharacterData extends CharacterData:
	func _init() -> void:
		is_hero = false
		is_boss = false
		character_uid = "test_char"


## Mock BattleData for testing victory/defeat conditions
class MockBattleData extends BattleData:
	func _init() -> void:
		victory_condition = VictoryCondition.DEFEAT_ALL_ENEMIES
		defeat_condition = DefeatCondition.LEADER_DEFEATED
		victory_boss_index = -1
		victory_turn_count = 5
		defeat_turn_limit = 10
		gold_reward = 0
		item_rewards = []


# =============================================================================
# TEST SETUP
# =============================================================================

var _mock_units: Array[MockUnit] = []
var _mock_battle_data: MockBattleData = null
var _original_battle_data: BattleData = null
var _original_all_units: Array[Unit] = []
var _original_turn_number: int = 0
var _original_battle_active: bool = false

# Signal connection tracking for cleanup
var _connected_signals: Array[Dictionary] = []


func before_test() -> void:
	# Save original TurnManager state
	_original_all_units = TurnManager.all_units.duplicate()
	_original_turn_number = TurnManager.turn_number
	_original_battle_active = TurnManager.battle_active
	_original_battle_data = BattleManager.current_battle_data

	# Create fresh mock data
	_mock_units.clear()
	_mock_battle_data = MockBattleData.new()

	# Set up TurnManager for testing
	TurnManager.battle_active = true
	TurnManager.turn_number = 1


func after_test() -> void:
	# Disconnect any signals that were connected during the test
	for connection: Dictionary in _connected_signals:
		var sig: Signal = connection.signal_ref
		var callable: Callable = connection.callable
		if sig.is_connected(callable):
			sig.disconnect(callable)
	_connected_signals.clear()

	# Restore original TurnManager state
	TurnManager.all_units = _original_all_units
	TurnManager.turn_number = _original_turn_number
	TurnManager.battle_active = _original_battle_active
	BattleManager.current_battle_data = _original_battle_data

	# Clean up mock units
	for unit: MockUnit in _mock_units:
		if is_instance_valid(unit):
			unit.queue_free()
	_mock_units.clear()
	_mock_battle_data = null


## Helper to connect a signal and track it for cleanup
func _connect_signal(sig: Signal, callable: Callable) -> void:
	sig.connect(callable)
	_connected_signals.append({"signal_ref": sig, "callable": callable})


## Helper to create and register a mock unit
func _create_mock_unit(p_faction: String, alive: bool = true) -> MockUnit:
	var unit: MockUnit = MockUnit.new()
	unit.faction = p_faction
	unit._mock_is_alive = alive
	unit.character_data = MockCharacterData.new()
	_mock_units.append(unit)
	return unit


## Helper to set up TurnManager with mock units
func _setup_turn_manager_units(units: Array[MockUnit]) -> void:
	var typed_units: Array[Unit] = []
	for unit: MockUnit in units:
		typed_units.append(unit)
	TurnManager.all_units = typed_units
	BattleManager.current_battle_data = _mock_battle_data


# =============================================================================
# VICTORY CONDITION: DEFEAT_ALL_ENEMIES
# =============================================================================

func test_victory_defeat_all_enemies_no_enemies_left() -> void:
	# Setup: 2 player units alive, 0 enemy units
	var player1: MockUnit = _create_mock_unit("player", true)
	var player2: MockUnit = _create_mock_unit("player", true)
	player1.set_hero(true)

	_mock_battle_data.victory_condition = BattleData.VictoryCondition.DEFEAT_ALL_ENEMIES
	_setup_turn_manager_units([player1, player2])

	# Act
	var result: String = TurnManager._check_victory_condition(_mock_battle_data, 0, true)

	# Assert
	assert_str(result).is_equal("victory")


func test_victory_defeat_all_enemies_enemies_remain() -> void:
	# Setup: 2 player units, 1 enemy alive
	var player1: MockUnit = _create_mock_unit("player", true)
	var enemy1: MockUnit = _create_mock_unit("enemy", true)
	player1.set_hero(true)

	_mock_battle_data.victory_condition = BattleData.VictoryCondition.DEFEAT_ALL_ENEMIES
	_setup_turn_manager_units([player1, enemy1])

	# Act
	var result: String = TurnManager._check_victory_condition(_mock_battle_data, 1, true)

	# Assert
	assert_str(result).is_equal("")


func test_victory_defeat_all_enemies_only_dead_enemies() -> void:
	# Setup: 1 player alive, 2 dead enemies
	var player1: MockUnit = _create_mock_unit("player", true)
	var enemy1: MockUnit = _create_mock_unit("enemy", false)
	var enemy2: MockUnit = _create_mock_unit("enemy", false)
	player1.set_hero(true)

	_mock_battle_data.victory_condition = BattleData.VictoryCondition.DEFEAT_ALL_ENEMIES
	_setup_turn_manager_units([player1, enemy1, enemy2])

	# Act (enemy_count should be 0 since both are dead)
	var result: String = TurnManager._check_victory_condition(_mock_battle_data, 0, true)

	# Assert
	assert_str(result).is_equal("victory")


# =============================================================================
# VICTORY CONDITION: DEFEAT_BOSS
# =============================================================================

func test_victory_defeat_boss_boss_dead() -> void:
	# Setup: Boss is dead (boss_alive = false)
	var player1: MockUnit = _create_mock_unit("player", true)
	var enemy1: MockUnit = _create_mock_unit("enemy", false)  # This is the boss, dead
	player1.set_hero(true)
	enemy1.set_boss(true)

	_mock_battle_data.victory_condition = BattleData.VictoryCondition.DEFEAT_BOSS
	_mock_battle_data.victory_boss_index = 0
	_setup_turn_manager_units([player1, enemy1])

	# Act
	var result: String = TurnManager._check_victory_condition(_mock_battle_data, 0, false)

	# Assert
	assert_str(result).is_equal("victory")


func test_victory_defeat_boss_boss_alive() -> void:
	# Setup: Boss is still alive
	var player1: MockUnit = _create_mock_unit("player", true)
	var enemy1: MockUnit = _create_mock_unit("enemy", true)  # Boss still alive
	player1.set_hero(true)
	enemy1.set_boss(true)

	_mock_battle_data.victory_condition = BattleData.VictoryCondition.DEFEAT_BOSS
	_mock_battle_data.victory_boss_index = 0
	_setup_turn_manager_units([player1, enemy1])

	# Act
	var result: String = TurnManager._check_victory_condition(_mock_battle_data, 1, true)

	# Assert
	assert_str(result).is_equal("")


func test_victory_defeat_boss_other_enemies_alive() -> void:
	# Setup: Boss dead but other enemies alive - still victory
	var player1: MockUnit = _create_mock_unit("player", true)
	var boss: MockUnit = _create_mock_unit("enemy", false)  # Boss dead
	var minion: MockUnit = _create_mock_unit("enemy", true)  # Minion alive
	player1.set_hero(true)
	boss.set_boss(true)

	_mock_battle_data.victory_condition = BattleData.VictoryCondition.DEFEAT_BOSS
	_mock_battle_data.victory_boss_index = 0
	_setup_turn_manager_units([player1, boss, minion])

	# Act (boss_alive = false, enemy_count = 1 but doesn't matter for DEFEAT_BOSS)
	var result: String = TurnManager._check_victory_condition(_mock_battle_data, 1, false)

	# Assert
	assert_str(result).is_equal("victory")


# =============================================================================
# VICTORY CONDITION: SURVIVE_TURNS
# =============================================================================

func test_victory_survive_turns_reached_target() -> void:
	# Setup: Turn 5, need to survive 5 turns
	var player1: MockUnit = _create_mock_unit("player", true)
	player1.set_hero(true)

	_mock_battle_data.victory_condition = BattleData.VictoryCondition.SURVIVE_TURNS
	_mock_battle_data.victory_turn_count = 5
	_setup_turn_manager_units([player1])

	TurnManager.turn_number = 5

	# Act
	var result: String = TurnManager._check_victory_condition(_mock_battle_data, 1, true)

	# Assert
	assert_str(result).is_equal("victory")


func test_victory_survive_turns_exceeded_target() -> void:
	# Setup: Turn 7, need to survive 5 turns
	var player1: MockUnit = _create_mock_unit("player", true)
	player1.set_hero(true)

	_mock_battle_data.victory_condition = BattleData.VictoryCondition.SURVIVE_TURNS
	_mock_battle_data.victory_turn_count = 5
	_setup_turn_manager_units([player1])

	TurnManager.turn_number = 7

	# Act
	var result: String = TurnManager._check_victory_condition(_mock_battle_data, 1, true)

	# Assert
	assert_str(result).is_equal("victory")


func test_victory_survive_turns_not_reached() -> void:
	# Setup: Turn 3, need to survive 5 turns
	var player1: MockUnit = _create_mock_unit("player", true)
	player1.set_hero(true)

	_mock_battle_data.victory_condition = BattleData.VictoryCondition.SURVIVE_TURNS
	_mock_battle_data.victory_turn_count = 5
	_setup_turn_manager_units([player1])

	TurnManager.turn_number = 3

	# Act
	var result: String = TurnManager._check_victory_condition(_mock_battle_data, 1, true)

	# Assert
	assert_str(result).is_equal("")


# =============================================================================
# DEFEAT CONDITION: ALL_UNITS_DEFEATED
# =============================================================================

func test_defeat_all_units_defeated() -> void:
	# Setup: All player units dead
	var player1: MockUnit = _create_mock_unit("player", false)
	var player2: MockUnit = _create_mock_unit("player", false)
	var enemy1: MockUnit = _create_mock_unit("enemy", true)
	# No hero set - testing pure ALL_UNITS_DEFEATED

	_mock_battle_data.defeat_condition = BattleData.DefeatCondition.ALL_UNITS_DEFEATED
	_setup_turn_manager_units([player1, player2, enemy1])

	# Act (player_count = 0, hero_alive = false)
	var result: String = TurnManager._check_defeat_condition(_mock_battle_data, 0, false)

	# Assert
	assert_str(result).is_equal("defeat")


func test_defeat_all_units_some_alive() -> void:
	# Setup: One player unit still alive (not hero)
	var player1: MockUnit = _create_mock_unit("player", true)
	var player2: MockUnit = _create_mock_unit("player", false)
	var enemy1: MockUnit = _create_mock_unit("enemy", true)
	# Note: No hero, so hero_alive logic doesn't apply

	_mock_battle_data.defeat_condition = BattleData.DefeatCondition.ALL_UNITS_DEFEATED
	_setup_turn_manager_units([player1, player2, enemy1])

	# Act (player_count = 1, hero_alive = true means we don't trigger hero defeat)
	var result: String = TurnManager._check_defeat_condition(_mock_battle_data, 1, true)

	# Assert
	assert_str(result).is_equal("")


# =============================================================================
# DEFEAT CONDITION: LEADER_DEFEATED (Hero Death)
# =============================================================================

func test_defeat_hero_dead() -> void:
	# Setup: Hero is dead - should trigger defeat regardless of other units
	var player1: MockUnit = _create_mock_unit("player", false)  # Dead hero
	var player2: MockUnit = _create_mock_unit("player", true)   # Other unit alive
	var enemy1: MockUnit = _create_mock_unit("enemy", true)
	player1.set_hero(true)

	_mock_battle_data.defeat_condition = BattleData.DefeatCondition.LEADER_DEFEATED
	_setup_turn_manager_units([player1, player2, enemy1])

	# Act (player_count = 1, hero_alive = false)
	var result: String = TurnManager._check_defeat_condition(_mock_battle_data, 1, false)

	# Assert
	assert_str(result).is_equal("defeat")


func test_defeat_hero_alive_others_dead() -> void:
	# Setup: Hero alive, but other units dead - no defeat
	var player1: MockUnit = _create_mock_unit("player", true)  # Hero alive
	var player2: MockUnit = _create_mock_unit("player", false) # Other unit dead
	var enemy1: MockUnit = _create_mock_unit("enemy", true)
	player1.set_hero(true)

	_mock_battle_data.defeat_condition = BattleData.DefeatCondition.LEADER_DEFEATED
	_setup_turn_manager_units([player1, player2, enemy1])

	# Act (player_count = 1, hero_alive = true)
	var result: String = TurnManager._check_defeat_condition(_mock_battle_data, 1, true)

	# Assert
	assert_str(result).is_equal("")


# =============================================================================
# DEFEAT CONDITION: TURN_LIMIT
# =============================================================================

func test_defeat_turn_limit_exceeded() -> void:
	# Setup: Turn 11, limit is 10
	var player1: MockUnit = _create_mock_unit("player", true)
	player1.set_hero(true)

	_mock_battle_data.defeat_condition = BattleData.DefeatCondition.TURN_LIMIT
	_mock_battle_data.defeat_turn_limit = 10
	_setup_turn_manager_units([player1])

	TurnManager.turn_number = 11

	# Act (player_count = 1, hero_alive = true)
	var result: String = TurnManager._check_defeat_condition(_mock_battle_data, 1, true)

	# Assert
	assert_str(result).is_equal("defeat")


func test_defeat_turn_limit_at_limit() -> void:
	# Setup: Turn 10, limit is 10 - should NOT trigger defeat (only > limit)
	var player1: MockUnit = _create_mock_unit("player", true)
	player1.set_hero(true)

	_mock_battle_data.defeat_condition = BattleData.DefeatCondition.TURN_LIMIT
	_mock_battle_data.defeat_turn_limit = 10
	_setup_turn_manager_units([player1])

	TurnManager.turn_number = 10

	# Act
	var result: String = TurnManager._check_defeat_condition(_mock_battle_data, 1, true)

	# Assert
	assert_str(result).is_equal("")


func test_defeat_turn_limit_under_limit() -> void:
	# Setup: Turn 5, limit is 10
	var player1: MockUnit = _create_mock_unit("player", true)
	player1.set_hero(true)

	_mock_battle_data.defeat_condition = BattleData.DefeatCondition.TURN_LIMIT
	_mock_battle_data.defeat_turn_limit = 10
	_setup_turn_manager_units([player1])

	TurnManager.turn_number = 5

	# Act
	var result: String = TurnManager._check_defeat_condition(_mock_battle_data, 1, true)

	# Assert
	assert_str(result).is_equal("")


func test_defeat_turn_limit_zero_disabled() -> void:
	# Setup: Turn limit is 0 (disabled) - should never trigger
	var player1: MockUnit = _create_mock_unit("player", true)
	player1.set_hero(true)

	_mock_battle_data.defeat_condition = BattleData.DefeatCondition.TURN_LIMIT
	_mock_battle_data.defeat_turn_limit = 0
	_setup_turn_manager_units([player1])

	TurnManager.turn_number = 100

	# Act
	var result: String = TurnManager._check_defeat_condition(_mock_battle_data, 1, true)

	# Assert
	assert_str(result).is_equal("")


# =============================================================================
# IS_BOSS_ALIVE HELPER TESTS
# =============================================================================

func test_is_boss_alive_by_index() -> void:
	# Setup: Boss at index 1, alive
	var enemy0: MockUnit = _create_mock_unit("enemy", true)
	var enemy1: MockUnit = _create_mock_unit("enemy", true)  # Boss
	enemy1.set_boss(true)

	_mock_battle_data.victory_boss_index = 1
	_setup_turn_manager_units([enemy0, enemy1])

	# Act
	var result: bool = TurnManager._is_boss_alive(_mock_battle_data)

	# Assert
	assert_bool(result).is_true()


func test_is_boss_alive_by_index_dead() -> void:
	# Setup: Boss at index 0, dead
	var enemy0: MockUnit = _create_mock_unit("enemy", false)  # Boss, dead
	var enemy1: MockUnit = _create_mock_unit("enemy", true)
	enemy0.set_boss(true)

	_mock_battle_data.victory_boss_index = 0
	_setup_turn_manager_units([enemy0, enemy1])

	# Act
	var result: bool = TurnManager._is_boss_alive(_mock_battle_data)

	# Assert
	assert_bool(result).is_false()


func test_is_boss_alive_fallback_to_flag() -> void:
	# Setup: No boss_index (-1), uses is_boss flag fallback
	var enemy0: MockUnit = _create_mock_unit("enemy", true)
	var enemy1: MockUnit = _create_mock_unit("enemy", true)  # Has is_boss flag
	enemy1.set_boss(true)

	_mock_battle_data.victory_boss_index = -1  # Triggers fallback
	_setup_turn_manager_units([enemy0, enemy1])

	# Act
	var result: bool = TurnManager._is_boss_alive(_mock_battle_data)

	# Assert
	assert_bool(result).is_true()


func test_is_boss_alive_fallback_no_boss() -> void:
	# Setup: No boss_index, no is_boss flags
	var enemy0: MockUnit = _create_mock_unit("enemy", true)
	var enemy1: MockUnit = _create_mock_unit("enemy", true)

	_mock_battle_data.victory_boss_index = -1
	_setup_turn_manager_units([enemy0, enemy1])

	# Act
	var result: bool = TurnManager._is_boss_alive(_mock_battle_data)

	# Assert
	assert_bool(result).is_false()


# =============================================================================
# MOD HOOK SIGNAL TESTS
# =============================================================================

var _victory_signal_received: bool = false
var _defeat_signal_received: bool = false
var _last_victory_context: Dictionary = {}
var _last_defeat_context: Dictionary = {}


func _on_victory_condition_check(_battle_data: Resource, context: Dictionary) -> void:
	_victory_signal_received = true
	_last_victory_context = context


func _on_defeat_condition_check(_battle_data: Resource, context: Dictionary) -> void:
	_defeat_signal_received = true
	_last_defeat_context = context


func _on_victory_override(_battle_data: Resource, context: Dictionary) -> void:
	context.result = "victory"


func _on_defeat_override(_battle_data: Resource, context: Dictionary) -> void:
	context.result = "defeat"


func _reset_signal_tracking() -> void:
	_victory_signal_received = false
	_defeat_signal_received = false
	_last_victory_context = {}
	_last_defeat_context = {}


func test_victory_signal_emitted() -> void:
	_reset_signal_tracking()
	_connect_signal(TurnManager.victory_condition_check, _on_victory_condition_check)

	var player1: MockUnit = _create_mock_unit("player", true)
	player1.set_hero(true)
	_mock_battle_data.victory_condition = BattleData.VictoryCondition.DEFEAT_ALL_ENEMIES
	_setup_turn_manager_units([player1])

	# Act
	TurnManager._check_victory_condition(_mock_battle_data, 1, true)

	# Assert
	assert_bool(_victory_signal_received).is_true()
	assert_bool("enemy_count" in _last_victory_context).is_true()
	assert_bool("turn_number" in _last_victory_context).is_true()
	# Signal cleanup handled by after_test()


func test_defeat_signal_emitted() -> void:
	_reset_signal_tracking()
	_connect_signal(TurnManager.defeat_condition_check, _on_defeat_condition_check)

	var player1: MockUnit = _create_mock_unit("player", true)
	player1.set_hero(true)
	_mock_battle_data.defeat_condition = BattleData.DefeatCondition.LEADER_DEFEATED
	_setup_turn_manager_units([player1])

	# Act
	TurnManager._check_defeat_condition(_mock_battle_data, 1, true)

	# Assert
	assert_bool(_defeat_signal_received).is_true()
	assert_bool("player_count" in _last_defeat_context).is_true()
	assert_bool("turn_number" in _last_defeat_context).is_true()
	# Signal cleanup handled by after_test()


func test_mod_can_override_victory() -> void:
	_reset_signal_tracking()
	_connect_signal(TurnManager.victory_condition_check, _on_victory_override)

	var player1: MockUnit = _create_mock_unit("player", true)
	var enemy1: MockUnit = _create_mock_unit("enemy", true)  # Enemy still alive
	player1.set_hero(true)
	_mock_battle_data.victory_condition = BattleData.VictoryCondition.DEFEAT_ALL_ENEMIES
	_setup_turn_manager_units([player1, enemy1])

	# Act - normally would NOT be victory (enemy alive)
	var result: String = TurnManager._check_victory_condition(_mock_battle_data, 1, true)

	# Assert - mod forced victory
	assert_str(result).is_equal("victory")
	# Signal cleanup handled by after_test()


func test_mod_can_override_defeat() -> void:
	_reset_signal_tracking()
	_connect_signal(TurnManager.defeat_condition_check, _on_defeat_override)

	var player1: MockUnit = _create_mock_unit("player", true)
	var enemy1: MockUnit = _create_mock_unit("enemy", true)
	player1.set_hero(true)
	_mock_battle_data.defeat_condition = BattleData.DefeatCondition.LEADER_DEFEATED
	_setup_turn_manager_units([player1, enemy1])

	# Act - normally would NOT be defeat (hero alive)
	var result: String = TurnManager._check_defeat_condition(_mock_battle_data, 1, true)

	# Assert - mod forced defeat
	assert_str(result).is_equal("defeat")
	# Signal cleanup handled by after_test()


# =============================================================================
# NULL BATTLE DATA TESTS
# =============================================================================

func test_victory_no_battle_data_defaults_to_all_enemies() -> void:
	# Setup: No battle data, but all enemies dead
	var player1: MockUnit = _create_mock_unit("player", true)
	player1.set_hero(true)
	_setup_turn_manager_units([player1])
	BattleManager.current_battle_data = null

	# Act
	var result: String = TurnManager._check_victory_condition(null, 0, true)

	# Assert - should win with default condition
	assert_str(result).is_equal("victory")


func test_victory_no_battle_data_enemies_remain() -> void:
	# Setup: No battle data, enemies still alive
	var player1: MockUnit = _create_mock_unit("player", true)
	var enemy1: MockUnit = _create_mock_unit("enemy", true)
	player1.set_hero(true)
	_setup_turn_manager_units([player1, enemy1])
	BattleManager.current_battle_data = null

	# Act
	var result: String = TurnManager._check_victory_condition(null, 1, true)

	# Assert - should not win
	assert_str(result).is_equal("")


func test_defeat_no_battle_data_hero_dead() -> void:
	# Setup: No battle data, hero dead
	var player1: MockUnit = _create_mock_unit("player", false)
	player1.set_hero(true)
	_setup_turn_manager_units([player1])
	BattleManager.current_battle_data = null

	# Act (hero_alive = false always triggers defeat)
	var result: String = TurnManager._check_defeat_condition(null, 0, false)

	# Assert
	assert_str(result).is_equal("defeat")
