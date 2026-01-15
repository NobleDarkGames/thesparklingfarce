## Unit Tests for SaveManager sync_current_save_state
##
## Tests the synchronization of runtime state to SaveData before persistence.
##
## AUTOLOAD DEPENDENCY: These tests require the following autoloads to be active:
##   - SaveManager: The system under test
##   - GameState: Provides story_flags that get synced
##   - PartyManager: Provides party data that gets synced
##
## Unlike StorageManager (which can be instantiated fresh), SaveManager's sync
## functionality integrates with multiple autoloads, so we test against the
## live singleton and carefully restore state after each test.
class_name TestSaveManager
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

## Stores the original current_save to restore after each test
var _original_save: SaveData


func before_test() -> void:
	# Preserve original state so we can restore it
	_original_save = SaveManager.current_save


func after_test() -> void:
	# Restore original state to avoid contaminating other tests
	SaveManager.current_save = _original_save


# =============================================================================
# NULL SAFETY TESTS
# =============================================================================

func test_sync_handles_null_current_save() -> void:
	# Set current_save to null
	SaveManager.current_save = null

	# Should not crash - just early return with a warning
	SaveManager.sync_current_save_state()

	# If we got here without crashing, the test passes
	assert_bool(true).is_true()


# =============================================================================
# TIMESTAMP SYNC TESTS
# =============================================================================

func test_sync_updates_last_played_timestamp() -> void:
	# Create a test save with timestamp set to 0 (epoch)
	var test_save: SaveData = SaveData.new()
	test_save.last_played_timestamp = 0
	SaveManager.current_save = test_save

	# Sync should update the timestamp to current time
	SaveManager.sync_current_save_state()

	# Timestamp should now be greater than 0 (current Unix time)
	var timestamp_updated: bool = test_save.last_played_timestamp > 0
	assert_bool(timestamp_updated).is_true()


func test_sync_timestamp_is_recent() -> void:
	# Create a test save with old timestamp
	var test_save: SaveData = SaveData.new()
	test_save.last_played_timestamp = 0
	SaveManager.current_save = test_save

	# Record time before sync
	var before_sync: int = int(Time.get_unix_time_from_system())

	SaveManager.sync_current_save_state()

	# Record time after sync
	var after_sync: int = int(Time.get_unix_time_from_system())

	# Timestamp should be within the sync window (allowing for execution time)
	var timestamp: int = test_save.last_played_timestamp
	var is_within_window: bool = timestamp >= before_sync and timestamp <= after_sync
	assert_bool(is_within_window).is_true()


# =============================================================================
# STORY FLAGS SYNC TESTS
# =============================================================================

func test_sync_copies_story_flags_from_game_state() -> void:
	# Create a unique test flag to avoid collision with real flags
	var test_flag: String = "_test_sync_flag_" + str(randi())

	# Set the flag in GameState
	GameState.set_flag(test_flag, true)

	# Create test save with empty flags
	var test_save: SaveData = SaveData.new()
	test_save.story_flags = {}
	SaveManager.current_save = test_save

	# Sync should copy flags from GameState
	SaveManager.sync_current_save_state()

	# Verify the flag was copied to save data
	var flag_copied: bool = test_flag in test_save.story_flags

	# Clean up test flag from GameState
	GameState.clear_flag(test_flag)

	assert_bool(flag_copied).is_true()


func test_sync_copies_flag_values_correctly() -> void:
	# Create unique test flags
	var true_flag: String = "_test_true_flag_" + str(randi())
	var false_flag: String = "_test_false_flag_" + str(randi())

	# Set flags with different values in GameState
	GameState.set_flag(true_flag, true)
	GameState.set_flag(false_flag, false)

	# Create test save
	var test_save: SaveData = SaveData.new()
	test_save.story_flags = {}
	SaveManager.current_save = test_save

	SaveManager.sync_current_save_state()

	# Verify flag values were preserved
	var true_value_correct: bool = test_save.story_flags.get(true_flag, false) == true
	var false_value_correct: bool = test_save.story_flags.get(false_flag, true) == false

	# Clean up
	GameState.clear_flag(true_flag)
	GameState.clear_flag(false_flag)

	assert_bool(true_value_correct).is_true()
	assert_bool(false_value_correct).is_true()


func test_sync_overwrites_existing_flags() -> void:
	# Create a unique test flag
	var test_flag: String = "_test_overwrite_flag_" + str(randi())

	# Set flag to true in GameState
	GameState.set_flag(test_flag, true)

	# Create test save with the same flag set to false
	var test_save: SaveData = SaveData.new()
	test_save.story_flags = {test_flag: false}
	SaveManager.current_save = test_save

	SaveManager.sync_current_save_state()

	# The sync should overwrite with GameState's value
	var value_overwritten: bool = test_save.story_flags.get(test_flag, false) == true

	# Clean up
	GameState.clear_flag(test_flag)

	assert_bool(value_overwritten).is_true()
