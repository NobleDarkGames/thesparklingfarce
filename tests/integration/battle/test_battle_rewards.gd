## Unit Tests for Battle Rewards Distribution in BattleManager
##
## Tests the _distribute_battle_rewards() method including:
## - Gold distribution via SaveManager
## - Pre/post reward signals for mod hooks
## - Return value structure
##
## NOTE: Item distribution tests are limited because BattleManager._distribute_battle_rewards()
## uses typed iteration `for item: ItemData in ...` which requires actual ItemData instances.
## ItemData resources must have an item_id property for rewards to work correctly.
##
## These are unit tests using mock objects to minimize dependencies.
class_name TestBattleRewards
extends GdUnitTestSuite


const SignalTrackerScript: GDScript = preload("res://tests/fixtures/signal_tracker.gd")


# =============================================================================
# TEST FIXTURES - Mock Objects
# =============================================================================

## Mock BattleData for testing rewards (gold only - no items)
class MockBattleData extends BattleData:
	func _init() -> void:
		battle_name = "Test Battle"
		gold_reward = 0
		item_rewards = []  # Empty - item tests require real ItemData
		victory_condition = VictoryCondition.DEFEAT_ALL_ENEMIES
		defeat_condition = DefeatCondition.LEADER_DEFEATED


# =============================================================================
# TEST SETUP
# =============================================================================

var _mock_battle_data: MockBattleData = null
var _original_battle_data: Resource = null
var _original_save: Resource = null
var _original_gold: int = 0
var _original_depot_items: Array = []

# Signal tracker for cleanup
var _tracker: RefCounted  # SignalTracker type


func before_test() -> void:
	_tracker = SignalTrackerScript.new()
	# Save original state
	_original_battle_data = BattleManager.current_battle_data
	if SaveManager.current_save:
		_original_gold = SaveManager.current_save.gold
		_original_depot_items = SaveManager.current_save.depot_items.duplicate()
	_original_save = SaveManager.current_save

	# Create test save data if none exists
	if not SaveManager.current_save:
		SaveManager.current_save = SaveData.new()

	# Reset to known state
	SaveManager.current_save.gold = 0
	SaveManager.current_save.depot_items.clear()

	# Create fresh mock data
	_mock_battle_data = MockBattleData.new()
	BattleManager.current_battle_data = _mock_battle_data


func after_test() -> void:
	# Disconnect all tracked signals
	_tracker.disconnect_all()
	_tracker = null

	# Restore original state
	BattleManager.current_battle_data = _original_battle_data
	if _original_save:
		SaveManager.current_save = _original_save
		SaveManager.current_save.gold = _original_gold
		SaveManager.current_save.depot_items = _original_depot_items
	_mock_battle_data = null


## Helper to connect a signal and track it for cleanup
func _connect_signal(sig: Signal, callable: Callable) -> void:
	_tracker.track_with_callback(sig, callable)


# =============================================================================
# GOLD DISTRIBUTION TESTS
# =============================================================================

func test_distribute_gold_basic() -> void:
	# Setup
	_mock_battle_data.gold_reward = 100
	SaveManager.current_save.gold = 50

	# Act
	var rewards: Dictionary = BattleManager._distribute_battle_rewards()

	# Assert
	assert_int(rewards.gold).is_equal(100)
	assert_int(SaveManager.current_save.gold).is_equal(150)


func test_distribute_gold_zero() -> void:
	# Setup
	_mock_battle_data.gold_reward = 0
	SaveManager.current_save.gold = 50

	# Act
	var rewards: Dictionary = BattleManager._distribute_battle_rewards()

	# Assert
	assert_int(rewards.gold).is_equal(0)
	assert_int(SaveManager.current_save.gold).is_equal(50)


func test_distribute_gold_large_amount() -> void:
	# Setup
	_mock_battle_data.gold_reward = 999999
	SaveManager.current_save.gold = 1

	# Act
	var rewards: Dictionary = BattleManager._distribute_battle_rewards()

	# Assert
	assert_int(rewards.gold).is_equal(999999)
	assert_int(SaveManager.current_save.gold).is_equal(1000000)


func test_distribute_gold_uses_save_manager() -> void:
	# Setup - verify we're using SaveManager.add_current_gold()
	_mock_battle_data.gold_reward = 200
	var initial: int = SaveManager.get_current_gold()

	# Act
	BattleManager._distribute_battle_rewards()

	# Assert
	assert_int(SaveManager.get_current_gold()).is_equal(initial + 200)


func test_distribute_gold_preserves_existing() -> void:
	# Setup
	SaveManager.current_save.gold = 9999
	_mock_battle_data.gold_reward = 1

	# Act
	BattleManager._distribute_battle_rewards()

	# Assert
	assert_int(SaveManager.current_save.gold).is_equal(10000)


func test_distribute_gold_adds_to_zero() -> void:
	# Setup - starting from zero gold
	SaveManager.current_save.gold = 0
	_mock_battle_data.gold_reward = 500

	# Act
	BattleManager._distribute_battle_rewards()

	# Assert
	assert_int(SaveManager.current_save.gold).is_equal(500)


# =============================================================================
# EMPTY ITEMS ARRAY TESTS
# =============================================================================

func test_distribute_no_items() -> void:
	# Setup
	_mock_battle_data.item_rewards = []

	# Act
	var rewards: Dictionary = BattleManager._distribute_battle_rewards()

	# Assert
	assert_int(rewards.items.size()).is_equal(0)
	assert_int(SaveManager.current_save.depot_items.size()).is_equal(0)


func test_distribute_empty_item_rewards_array() -> void:
	# Setup - simulate unset item_rewards (empty array)
	_mock_battle_data.item_rewards = []
	_mock_battle_data.gold_reward = 100

	# Act
	var rewards: Dictionary = BattleManager._distribute_battle_rewards()

	# Assert - gold works, items empty
	assert_int(rewards.gold).is_equal(100)
	assert_int(rewards.items.size()).is_equal(0)


# =============================================================================
# NO BATTLE DATA TESTS
# =============================================================================

func test_distribute_no_battle_data() -> void:
	# Setup
	BattleManager.current_battle_data = null
	SaveManager.current_save.gold = 100

	# Act
	var rewards: Dictionary = BattleManager._distribute_battle_rewards()

	# Assert - should return empty rewards, no errors
	assert_int(rewards.gold).is_equal(0)
	assert_int(rewards.items.size()).is_equal(0)
	assert_int(SaveManager.current_save.gold).is_equal(100)  # Unchanged


func test_distribute_no_battle_data_returns_empty_dict() -> void:
	# Setup
	BattleManager.current_battle_data = null

	# Act
	var rewards: Dictionary = BattleManager._distribute_battle_rewards()

	# Assert - verify structure even with no data
	assert_bool("gold" in rewards).is_true()
	assert_bool("items" in rewards).is_true()
	assert_int(rewards.gold).is_equal(0)
	assert_bool(rewards.items is Array).is_true()


# =============================================================================
# SIGNAL TESTS
# =============================================================================

var _pre_rewards_received: bool = false
var _post_rewards_received: bool = false
var _last_pre_battle_data: Resource = null
var _last_pre_rewards: Dictionary = {}
var _last_post_battle_data: Resource = null
var _last_post_rewards: Dictionary = {}


func _on_pre_battle_rewards(battle_data: Resource, rewards: Dictionary) -> void:
	_pre_rewards_received = true
	_last_pre_battle_data = battle_data
	_last_pre_rewards = rewards.duplicate()


func _on_post_battle_rewards(battle_data: Resource, rewards: Dictionary) -> void:
	_post_rewards_received = true
	_last_post_battle_data = battle_data
	_last_post_rewards = rewards.duplicate()


func _reset_signal_tracking() -> void:
	_pre_rewards_received = false
	_post_rewards_received = false
	_last_pre_battle_data = null
	_last_pre_rewards = {}
	_last_post_battle_data = null
	_last_post_rewards = {}


func test_pre_battle_rewards_signal_emitted() -> void:
	_reset_signal_tracking()
	_connect_signal(GameEventBus.pre_battle_rewards, _on_pre_battle_rewards)

	_mock_battle_data.gold_reward = 100

	# Act
	BattleManager._distribute_battle_rewards()

	# Assert
	assert_bool(_pre_rewards_received).is_true()
	assert_object(_last_pre_battle_data).is_equal(_mock_battle_data)
	assert_int(_last_pre_rewards.gold).is_equal(100)
	# Signal cleanup handled by after_test()


func test_post_battle_rewards_signal_emitted() -> void:
	_reset_signal_tracking()
	_connect_signal(GameEventBus.post_battle_rewards, _on_post_battle_rewards)

	_mock_battle_data.gold_reward = 250

	# Act
	BattleManager._distribute_battle_rewards()

	# Assert
	assert_bool(_post_rewards_received).is_true()
	assert_object(_last_post_battle_data).is_equal(_mock_battle_data)
	assert_int(_last_post_rewards.gold).is_equal(250)
	# Signal cleanup handled by after_test()


func test_mod_can_modify_gold_via_pre_signal() -> void:
	# Setup - mod that doubles gold
	var modifier_callback: Callable = func(_battle_data: Resource, rewards: Dictionary) -> void:
		rewards.gold = rewards.gold * 2

	_connect_signal(GameEventBus.pre_battle_rewards, modifier_callback)

	_mock_battle_data.gold_reward = 100
	SaveManager.current_save.gold = 0

	# Act
	var rewards: Dictionary = BattleManager._distribute_battle_rewards()

	# Assert - rewards should be modified
	assert_int(rewards.gold).is_equal(200)  # Doubled

	# Assert - modifications should be applied to save
	assert_int(SaveManager.current_save.gold).is_equal(200)
	# Signal cleanup handled by after_test()


func test_mod_can_add_bonus_items_via_pre_signal() -> void:
	# Setup - mod that adds bonus items via the pre signal
	var modifier_callback: Callable = func(_battle_data: Resource, rewards: Dictionary) -> void:
		rewards.items.append("bonus_item_from_mod")

	_connect_signal(GameEventBus.pre_battle_rewards, modifier_callback)

	_mock_battle_data.gold_reward = 50

	# Act
	var rewards: Dictionary = BattleManager._distribute_battle_rewards()

	# Assert - mod-added item should be in rewards
	assert_bool("bonus_item_from_mod" in rewards.items).is_true()

	# Assert - item should be in depot
	assert_bool("bonus_item_from_mod" in SaveManager.current_save.depot_items).is_true()
	# Signal cleanup handled by after_test()


func test_mod_can_zero_out_gold() -> void:
	# Setup - mod that removes gold reward
	var punish_callback: Callable = func(_battle_data: Resource, rewards: Dictionary) -> void:
		rewards.gold = 0

	_connect_signal(GameEventBus.pre_battle_rewards, punish_callback)

	_mock_battle_data.gold_reward = 1000
	SaveManager.current_save.gold = 500

	# Act
	var rewards: Dictionary = BattleManager._distribute_battle_rewards()

	# Assert
	assert_int(rewards.gold).is_equal(0)
	assert_int(SaveManager.current_save.gold).is_equal(500)  # Unchanged
	# Signal cleanup handled by after_test()


func test_signals_order_pre_before_post() -> void:
	# Setup
	var call_order: Array[String] = []

	var pre_callback: Callable = func(_bd: Resource, _r: Dictionary) -> void:
		call_order.append("pre")

	var post_callback: Callable = func(_bd: Resource, _r: Dictionary) -> void:
		call_order.append("post")

	_connect_signal(GameEventBus.pre_battle_rewards, pre_callback)
	_connect_signal(GameEventBus.post_battle_rewards, post_callback)

	_mock_battle_data.gold_reward = 50

	# Act
	BattleManager._distribute_battle_rewards()

	# Assert
	assert_int(call_order.size()).is_equal(2)
	assert_str(call_order[0]).is_equal("pre")
	assert_str(call_order[1]).is_equal("post")
	# Signal cleanup handled by after_test()


func test_pre_signal_modifications_reflected_in_post_signal() -> void:
	# Setup - pre callback modifies, post callback receives modified values
	var pre_callback: Callable = func(_bd: Resource, rewards: Dictionary) -> void:
		rewards.gold = 9999
		rewards.items.append("special_reward")

	_reset_signal_tracking()
	_connect_signal(GameEventBus.pre_battle_rewards, pre_callback)
	_connect_signal(GameEventBus.post_battle_rewards, _on_post_battle_rewards)

	_mock_battle_data.gold_reward = 100

	# Act
	BattleManager._distribute_battle_rewards()

	# Assert - post signal should have the modified values
	assert_int(_last_post_rewards.gold).is_equal(9999)
	assert_bool("special_reward" in _last_post_rewards.items).is_true()
	# Signal cleanup handled by after_test()


# =============================================================================
# RETURN VALUE STRUCTURE TESTS
# =============================================================================

func test_rewards_dictionary_structure() -> void:
	# Setup
	_mock_battle_data.gold_reward = 150

	# Act
	var rewards: Dictionary = BattleManager._distribute_battle_rewards()

	# Assert - verify structure
	assert_bool("gold" in rewards).is_true()
	assert_bool("items" in rewards).is_true()
	assert_bool(rewards.gold is int).is_true()
	assert_bool(rewards.items is Array).is_true()


func test_rewards_returns_actual_distributed_gold() -> void:
	# Setup
	_mock_battle_data.gold_reward = 777

	# Act
	var rewards: Dictionary = BattleManager._distribute_battle_rewards()

	# Assert - return value matches what was configured
	assert_int(rewards.gold).is_equal(777)


func test_rewards_empty_when_no_rewards_configured() -> void:
	# Setup - no gold, no items
	_mock_battle_data.gold_reward = 0
	_mock_battle_data.item_rewards = []

	# Act
	var rewards: Dictionary = BattleManager._distribute_battle_rewards()

	# Assert
	assert_int(rewards.gold).is_equal(0)
	assert_int(rewards.items.size()).is_equal(0)


# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_distribute_with_no_save_data_gold() -> void:
	# Setup - temporarily remove save data
	var temp_save: SaveData = SaveManager.current_save
	SaveManager.current_save = null

	_mock_battle_data.gold_reward = 100

	# Act
	var rewards: Dictionary = BattleManager._distribute_battle_rewards()

	# Assert - should return rewards dict but gold not added (no save)
	assert_int(rewards.gold).is_equal(100)

	# Restore
	SaveManager.current_save = temp_save


func test_distribute_preserves_existing_depot_items() -> void:
	# Setup - existing items in depot
	SaveManager.current_save.depot_items.append("existing_item_1")
	SaveManager.current_save.depot_items.append("existing_item_2")

	# No new items from battle
	_mock_battle_data.item_rewards = []
	_mock_battle_data.gold_reward = 10

	# Act
	BattleManager._distribute_battle_rewards()

	# Assert - existing items preserved
	assert_int(SaveManager.current_save.depot_items.size()).is_equal(2)
	assert_bool("existing_item_1" in SaveManager.current_save.depot_items).is_true()
	assert_bool("existing_item_2" in SaveManager.current_save.depot_items).is_true()


func test_multiple_distributions_accumulate() -> void:
	# Setup - simulate multiple battles
	SaveManager.current_save.gold = 0
	_mock_battle_data.gold_reward = 100

	# Act - distribute three times
	BattleManager._distribute_battle_rewards()
	BattleManager._distribute_battle_rewards()
	BattleManager._distribute_battle_rewards()

	# Assert - gold accumulated
	assert_int(SaveManager.current_save.gold).is_equal(300)
