## GameState Unit Tests
##
## Tests the GameState functionality:
## - Story flag management (set/get/has/clear)
## - Trigger completion tracking
## - Campaign data management
## - Signal emissions on state changes
## - Default value handling
## - State export/import
##
## Note: This is a UNIT test - creates a fresh GameState instance,
## does not use the autoload singleton.
class_name TestGameState
extends GdUnitTestSuite


# =============================================================================
# TEST CONSTANTS
# =============================================================================

const TEST_MOD_ID: String = "_test_game_state"


# =============================================================================
# TEST FIXTURES
# =============================================================================

const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")
const GameStateScript = preload("res://core/systems/game_state.gd")

var _game_state: Node
var _tracker: SignalTracker


func before_test() -> void:
	# Create a fresh GameState instance for each test
	_game_state = GameStateScript.new()
	add_child(_game_state)
	_tracker = SignalTrackerScript.new()


func after_test() -> void:
	if _tracker:
		_tracker.disconnect_all()
		_tracker = null
	if _game_state and is_instance_valid(_game_state):
		_game_state.queue_free()
	_game_state = null


# =============================================================================
# STORY FLAG TESTS
# =============================================================================

func test_has_flag_returns_false_for_unset_flag() -> void:
	var result: bool = _game_state.has_flag("nonexistent_flag")

	assert_bool(result).is_false()


func test_set_flag_stores_true_value() -> void:
	_game_state.set_flag("test_flag", true)

	var result: bool = _game_state.has_flag("test_flag")

	assert_bool(result).is_true()


func test_set_flag_default_value_is_true() -> void:
	_game_state.set_flag("default_test")

	var result: bool = _game_state.has_flag("default_test")

	assert_bool(result).is_true()


func test_set_flag_can_set_false() -> void:
	_game_state.set_flag("false_flag", false)

	var result: bool = _game_state.has_flag("false_flag")

	assert_bool(result).is_false()


func test_clear_flag_sets_flag_to_false() -> void:
	_game_state.set_flag("to_clear", true)

	_game_state.clear_flag("to_clear")

	assert_bool(_game_state.has_flag("to_clear")).is_false()


func test_set_flag_emits_flag_changed_signal() -> void:
	_tracker.track(_game_state.flag_changed)

	_game_state.set_flag("signal_test", true)

	assert_bool(_tracker.was_emitted("flag_changed")).is_true()


func test_set_flag_emits_signal_with_flag_name_and_value() -> void:
	_tracker.track(_game_state.flag_changed)

	_game_state.set_flag("detailed_test", true)

	var emissions: Array = _tracker.get_emissions("flag_changed")
	assert_int(emissions.size()).is_equal(1)
	assert_str(emissions[0].arguments[0]).is_equal("detailed_test")
	assert_bool(emissions[0].arguments[1]).is_true()


func test_set_flag_does_not_emit_if_value_unchanged() -> void:
	_game_state.set_flag("no_change", true)
	_tracker.clear_emissions()
	_tracker.track(_game_state.flag_changed)

	_game_state.set_flag("no_change", true)

	assert_bool(_tracker.was_emitted("flag_changed")).is_false()


func test_flag_names_are_case_sensitive() -> void:
	_game_state.set_flag("TestFlag", true)
	_game_state.set_flag("testflag", false)

	assert_bool(_game_state.has_flag("TestFlag")).is_true()
	assert_bool(_game_state.has_flag("testflag")).is_false()


func test_empty_string_flag_name_works() -> void:
	# Edge case: empty string flag names should not crash
	_game_state.set_flag("", true)

	assert_bool(_game_state.has_flag("")).is_true()


# =============================================================================
# TRIGGER COMPLETION TESTS
# =============================================================================

func test_is_trigger_completed_returns_false_for_uncompleted() -> void:
	var result: bool = _game_state.is_trigger_completed("test_trigger")

	assert_bool(result).is_false()


func test_set_trigger_completed_marks_trigger() -> void:
	_game_state.set_trigger_completed("test_trigger")

	var result: bool = _game_state.is_trigger_completed("test_trigger")

	assert_bool(result).is_true()


func test_set_trigger_completed_emits_signal() -> void:
	_tracker.track(_game_state.trigger_completed)

	_game_state.set_trigger_completed("signal_trigger")

	assert_bool(_tracker.was_emitted("trigger_completed")).is_true()


func test_set_trigger_completed_emits_trigger_id() -> void:
	_tracker.track(_game_state.trigger_completed)

	_game_state.set_trigger_completed("named_trigger")

	var emissions: Array = _tracker.get_emissions("trigger_completed")
	assert_int(emissions.size()).is_equal(1)
	assert_str(emissions[0].arguments[0]).is_equal("named_trigger")


func test_set_trigger_completed_does_not_emit_if_already_completed() -> void:
	_game_state.set_trigger_completed("already_done")
	_tracker.clear_emissions()
	_tracker.track(_game_state.trigger_completed)

	_game_state.set_trigger_completed("already_done")

	assert_bool(_tracker.was_emitted("trigger_completed")).is_false()


func test_reset_trigger_allows_reactivation() -> void:
	_game_state.set_trigger_completed("resettable")

	_game_state.reset_trigger("resettable")

	assert_bool(_game_state.is_trigger_completed("resettable")).is_false()


func test_reset_trigger_on_nonexistent_does_not_crash() -> void:
	# Should not crash when resetting a trigger that was never set
	_game_state.reset_trigger("never_existed")

	assert_bool(_game_state.is_trigger_completed("never_existed")).is_false()


# =============================================================================
# CAMPAIGN DATA TESTS
# =============================================================================

func test_get_campaign_data_returns_default_values() -> void:
	# GameState initializes with default campaign_data
	var chapter: Variant = _game_state.get_campaign_data("current_chapter")

	assert_int(chapter).is_equal(0)


func test_get_campaign_data_returns_default_for_unknown_key() -> void:
	var result: Variant = _game_state.get_campaign_data("unknown_key", 42)

	assert_int(result).is_equal(42)


func test_set_campaign_data_stores_value() -> void:
	_game_state.set_campaign_data("battles_won", 5)

	var result: Variant = _game_state.get_campaign_data("battles_won")

	assert_int(result).is_equal(5)


func test_set_campaign_data_emits_signal() -> void:
	_tracker.track(_game_state.campaign_data_changed)

	_game_state.set_campaign_data("treasures_found", 10)

	assert_bool(_tracker.was_emitted("campaign_data_changed")).is_true()


func test_set_campaign_data_emits_key_and_value() -> void:
	_tracker.track(_game_state.campaign_data_changed)

	_game_state.set_campaign_data("current_chapter", 2)

	var emissions: Array = _tracker.get_emissions("campaign_data_changed")
	assert_int(emissions.size()).is_equal(1)
	assert_str(emissions[0].arguments[0]).is_equal("current_chapter")
	assert_int(emissions[0].arguments[1]).is_equal(2)


func test_set_campaign_data_does_not_emit_if_unchanged() -> void:
	_game_state.set_campaign_data("stable_value", 100)
	_tracker.clear_emissions()
	_tracker.track(_game_state.campaign_data_changed)

	_game_state.set_campaign_data("stable_value", 100)

	assert_bool(_tracker.was_emitted("campaign_data_changed")).is_false()


func test_increment_campaign_data_adds_to_value() -> void:
	_game_state.set_campaign_data("battles_won", 5)

	_game_state.increment_campaign_data("battles_won", 3)

	var result: Variant = _game_state.get_campaign_data("battles_won")
	assert_int(result).is_equal(8)


func test_increment_campaign_data_default_amount_is_one() -> void:
	_game_state.set_campaign_data("counter", 10)

	_game_state.increment_campaign_data("counter")

	var result: Variant = _game_state.get_campaign_data("counter")
	assert_int(result).is_equal(11)


func test_increment_campaign_data_initializes_missing_key() -> void:
	# Incrementing a non-existent key should start from 0
	_game_state.increment_campaign_data("new_counter", 5)

	var result: Variant = _game_state.get_campaign_data("new_counter")
	assert_int(result).is_equal(5)


# =============================================================================
# STATE EXPORT/IMPORT TESTS
# =============================================================================

func test_export_state_includes_story_flags() -> void:
	_game_state.set_flag("export_flag", true)

	var state: Dictionary = _game_state.export_state()

	assert_bool("story_flags" in state).is_true()
	assert_bool(state.story_flags.get("export_flag", false)).is_true()


func test_export_state_includes_completed_triggers() -> void:
	_game_state.set_trigger_completed("export_trigger")

	var state: Dictionary = _game_state.export_state()

	assert_bool("completed_triggers" in state).is_true()
	assert_bool(state.completed_triggers.get("export_trigger", false)).is_true()


func test_export_state_includes_campaign_data() -> void:
	_game_state.set_campaign_data("battles_won", 42)

	var state: Dictionary = _game_state.export_state()

	assert_bool("campaign_data" in state).is_true()
	assert_int(state.campaign_data.get("battles_won", 0)).is_equal(42)


func test_import_state_restores_story_flags() -> void:
	var state: Dictionary = {
		"story_flags": {"imported_flag": true},
		"completed_triggers": {},
		"campaign_data": {}
	}

	_game_state.import_state(state)

	assert_bool(_game_state.has_flag("imported_flag")).is_true()


func test_import_state_restores_completed_triggers() -> void:
	var state: Dictionary = {
		"story_flags": {},
		"completed_triggers": {"imported_trigger": true},
		"campaign_data": {}
	}

	_game_state.import_state(state)

	assert_bool(_game_state.is_trigger_completed("imported_trigger")).is_true()


func test_import_state_restores_campaign_data() -> void:
	var state: Dictionary = {
		"story_flags": {},
		"completed_triggers": {},
		"campaign_data": {"treasures_found": 25}
	}

	_game_state.import_state(state)

	var result: Variant = _game_state.get_campaign_data("treasures_found")
	assert_int(result).is_equal(25)


func test_import_state_validates_flag_values() -> void:
	# Non-boolean flag values should be skipped
	var state: Dictionary = {
		"story_flags": {"valid_flag": true, "invalid_flag": "not_a_bool"},
		"completed_triggers": {},
		"campaign_data": {}
	}

	_game_state.import_state(state)

	assert_bool(_game_state.has_flag("valid_flag")).is_true()
	# Invalid flag should not be imported
	assert_bool("invalid_flag" in _game_state.story_flags).is_false()


func test_import_state_handles_missing_sections() -> void:
	# Import with partial state should use defaults for missing sections
	var state: Dictionary = {
		"story_flags": {"partial_flag": true}
		# completed_triggers and campaign_data missing
	}

	var result: bool = _game_state.import_state(state)

	assert_bool(result).is_true()
	assert_bool(_game_state.has_flag("partial_flag")).is_true()


# =============================================================================
# RESET_ALL TESTS
# =============================================================================

func test_reset_all_clears_story_flags() -> void:
	_game_state.set_flag("to_reset", true)

	_game_state.reset_all()

	assert_bool(_game_state.has_flag("to_reset")).is_false()


func test_reset_all_clears_completed_triggers() -> void:
	_game_state.set_trigger_completed("reset_trigger")

	_game_state.reset_all()

	assert_bool(_game_state.is_trigger_completed("reset_trigger")).is_false()


func test_reset_all_resets_campaign_data_to_defaults() -> void:
	_game_state.set_campaign_data("battles_won", 999)

	_game_state.reset_all()

	var result: Variant = _game_state.get_campaign_data("battles_won")
	assert_int(result).is_equal(0)


# =============================================================================
# NAMESPACED FLAG API TESTS
# =============================================================================

func test_set_mod_namespace_stores_namespace() -> void:
	_game_state.set_mod_namespace("my_mod")

	assert_str(_game_state.get_mod_namespace()).is_equal("my_mod")


func test_clear_mod_namespace_removes_namespace() -> void:
	_game_state.set_mod_namespace("my_mod")

	_game_state.clear_mod_namespace()

	assert_str(_game_state.get_mod_namespace()).is_empty()


func test_has_flag_scoped_uses_namespace() -> void:
	_game_state.set_mod_namespace(TEST_MOD_ID)
	_game_state.story_flags[TEST_MOD_ID + ":scoped_flag"] = true

	var result: bool = _game_state.has_flag_scoped("scoped_flag")

	assert_bool(result).is_true()


func test_set_flag_scoped_prefixes_with_namespace() -> void:
	_game_state.set_mod_namespace(TEST_MOD_ID)

	_game_state.set_flag_scoped("namespaced_flag", true)

	assert_bool(_game_state.story_flags.get(TEST_MOD_ID + ":namespaced_flag", false)).is_true()


func test_clear_flag_scoped_clears_namespaced_flag() -> void:
	_game_state.set_mod_namespace(TEST_MOD_ID)
	_game_state.set_flag_scoped("to_clear", true)

	_game_state.clear_flag_scoped("to_clear")

	assert_bool(_game_state.has_flag_scoped("to_clear")).is_false()


func test_get_flags_for_mod_returns_only_mod_flags() -> void:
	_game_state.story_flags[TEST_MOD_ID + ":flag_a"] = true
	_game_state.story_flags[TEST_MOD_ID + ":flag_b"] = false
	_game_state.story_flags["other_mod:flag_c"] = true

	var mod_flags: Dictionary = _game_state.get_flags_for_mod(TEST_MOD_ID)

	assert_int(mod_flags.size()).is_equal(2)
	assert_bool("flag_a" in mod_flags).is_true()
	assert_bool("flag_b" in mod_flags).is_true()
	assert_bool("flag_c" in mod_flags).is_false()


func test_is_flag_namespaced_detects_colon() -> void:
	assert_bool(_game_state.is_flag_namespaced("mod:flag")).is_true()
	assert_bool(_game_state.is_flag_namespaced("simple_flag")).is_false()


# =============================================================================
# SAFE LOCATION API TESTS
# =============================================================================

func test_set_last_safe_location_stores_path() -> void:
	_game_state.set_last_safe_location("res://scenes/town.tscn")

	assert_str(_game_state.get_last_safe_location()).is_equal("res://scenes/town.tscn")


func test_get_last_safe_location_returns_empty_if_not_set() -> void:
	# Fresh instance should have empty safe location
	assert_str(_game_state.last_safe_location).is_empty()


func test_set_last_safe_location_rejects_empty_path() -> void:
	_game_state.set_last_safe_location("res://valid/path.tscn")

	# Setting empty path should not overwrite valid path (warns instead)
	_game_state.set_last_safe_location("")

	assert_str(_game_state.last_safe_location).is_equal("res://valid/path.tscn")
