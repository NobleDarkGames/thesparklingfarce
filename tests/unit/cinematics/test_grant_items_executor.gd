## Unit Tests for GrantItemsExecutor
##
## Tests the grant_items cinematic command for granting items and gold.
class_name TestGrantItemsExecutor
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _executor: CinematicCommandExecutor
var _original_gold: int = 0


func before_test() -> void:
	# Load the executor
	var GrantItemsExecutor = preload("res://core/systems/cinematic_commands/grant_items_executor.gd")
	_executor = GrantItemsExecutor.new()
	# Store original gold to restore later
	if SaveManager and SaveManager.current_save:
		_original_gold = SaveManager.get_current_gold()


func after_test() -> void:
	_executor = null
	# Restore original gold
	if SaveManager and SaveManager.current_save:
		SaveManager.set_current_gold(_original_gold)


# =============================================================================
# EDITOR METADATA TESTS
# =============================================================================

func test_editor_metadata_exists() -> void:
	var metadata: Dictionary = _executor.get_editor_metadata()

	assert_bool(metadata.is_empty()).is_false()


func test_editor_metadata_has_description() -> void:
	var metadata: Dictionary = _executor.get_editor_metadata()

	assert_bool("description" in metadata).is_true()
	assert_str(metadata.get("description", "")).is_not_empty()


func test_editor_metadata_has_category() -> void:
	var metadata: Dictionary = _executor.get_editor_metadata()

	assert_bool("category" in metadata).is_true()
	assert_str(metadata.get("category", "")).is_equal("Rewards")


func test_editor_metadata_has_params() -> void:
	var metadata: Dictionary = _executor.get_editor_metadata()

	assert_bool("params" in metadata).is_true()
	var params: Dictionary = metadata.get("params", {})
	assert_bool("items" in params).is_true()
	assert_bool("gold" in params).is_true()
	assert_bool("recipient" in params).is_true()
	assert_bool("show_message" in params).is_true()
	assert_bool("silent" in params).is_true()


# =============================================================================
# GOLD GRANTING TESTS
# =============================================================================

func test_grants_gold_silently() -> void:
	# Skip if no save manager
	if not SaveManager or not SaveManager.current_save:
		return

	var starting_gold: int = SaveManager.get_current_gold()
	var command: Dictionary = {
		"type": "grant_items",
		"params": {
			"gold": 100,
			"silent": true
		}
	}

	# Create a mock manager (we only need it for state, which silent mode doesn't use)
	var result: bool = _executor.execute(command, null)

	# Silent mode returns true immediately
	assert_bool(result).is_true()
	assert_int(SaveManager.get_current_gold()).is_equal(starting_gold + 100)


func test_zero_gold_does_not_add() -> void:
	if not SaveManager or not SaveManager.current_save:
		return

	var starting_gold: int = SaveManager.get_current_gold()
	var command: Dictionary = {
		"type": "grant_items",
		"params": {
			"gold": 0,
			"silent": true
		}
	}

	_executor.execute(command, null)

	assert_int(SaveManager.get_current_gold()).is_equal(starting_gold)


# =============================================================================
# PARAMETER PARSING TESTS
# =============================================================================

func test_handles_empty_params() -> void:
	var command: Dictionary = {
		"type": "grant_items",
		"params": {}
	}

	# Should not crash with empty params
	var result: bool = _executor.execute(command, null)

	# Returns true because there's nothing to do
	assert_bool(result).is_true()


func test_handles_missing_params() -> void:
	var command: Dictionary = {
		"type": "grant_items"
	}

	# Should not crash with missing params
	var result: bool = _executor.execute(command, null)

	assert_bool(result).is_true()


func test_handles_items_as_string_array() -> void:
	# Items can be simple strings or dictionaries
	var command: Dictionary = {
		"type": "grant_items",
		"params": {
			"items": ["healing_herb", "antidote"],
			"silent": true
		}
	}

	# Should handle string array format without crashing
	var result: bool = _executor.execute(command, null)

	# Will return true (may fail to add items if hero doesn't exist, but won't crash)
	assert_bool(result).is_true()


func test_handles_items_as_dictionary_array() -> void:
	var command: Dictionary = {
		"type": "grant_items",
		"params": {
			"items": [
				{"item_id": "healing_herb", "quantity": 2},
				{"item_id": "antidote", "quantity": 1}
			],
			"silent": true
		}
	}

	# Should handle dictionary array format without crashing
	var result: bool = _executor.execute(command, null)

	assert_bool(result).is_true()


func test_silent_mode_returns_immediately() -> void:
	var command: Dictionary = {
		"type": "grant_items",
		"params": {
			"gold": 50,
			"items": [{"item_id": "healing_herb"}],
			"silent": true
		}
	}

	var result: bool = _executor.execute(command, null)

	# Silent mode always returns true (synchronous)
	assert_bool(result).is_true()
