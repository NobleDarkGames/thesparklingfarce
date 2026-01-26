## Unit Tests for AIModeRegistry
##
## Tests the AI mode registration system for behavior execution styles.
## Verifies mod extensibility, override behavior, and default mode presence.
class_name TestAIModeRegistry
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")

var _registry: RefCounted
var _tracker: RefCounted


func before_test() -> void:
	# Create a fresh registry for each test
	var AIModeRegistryClass: GDScript = load("res://core/registries/ai_mode_registry.gd")
	_registry = AIModeRegistryClass.new()
	_tracker = SignalTrackerScript.new()


func after_test() -> void:
	if _tracker:
		_tracker.disconnect_all()
		_tracker = null


# =============================================================================
# DEFAULT MODES TESTS
# =============================================================================

func test_default_modes_are_present() -> void:
	var mode_ids: Array[String] = _registry.get_mode_ids()

	assert_bool("aggressive" in mode_ids).is_true()
	assert_bool("cautious" in mode_ids).is_true()
	assert_bool("opportunistic" in mode_ids).is_true()


func test_default_mode_count() -> void:
	var stats: Dictionary = _registry.get_stats()

	# Should have exactly 3 default modes
	assert_int(stats.get("mode_count", 0)).is_equal(3)
	# No mod modes registered yet
	assert_int(stats.get("mod_mode_count", 0)).is_equal(0)


func test_is_default_mode_returns_true_for_defaults() -> void:
	assert_bool(_registry.is_default_mode("aggressive")).is_true()
	assert_bool(_registry.is_default_mode("cautious")).is_true()
	assert_bool(_registry.is_default_mode("opportunistic")).is_true()


func test_is_default_mode_returns_false_for_custom() -> void:
	var config: Dictionary = {
		"berserk": {
			"display_name": "Berserk",
			"description": "Ignores self-preservation"
		}
	}

	_registry.register_from_config("test_mod", config)

	assert_bool(_registry.is_default_mode("berserk")).is_false()


func test_default_modes_have_display_names() -> void:
	assert_str(_registry.get_display_name("aggressive")).is_equal("Aggressive")
	assert_str(_registry.get_display_name("cautious")).is_equal("Cautious")
	assert_str(_registry.get_display_name("opportunistic")).is_equal("Opportunistic")


func test_default_modes_have_descriptions() -> void:
	# Each default mode should have a non-empty description
	assert_str(_registry.get_description("aggressive")).is_not_empty()
	assert_str(_registry.get_description("cautious")).is_not_empty()
	assert_str(_registry.get_description("opportunistic")).is_not_empty()


# =============================================================================
# REGISTRATION FROM CONFIG TESTS
# =============================================================================

func test_register_from_config_adds_mode() -> void:
	var config: Dictionary = {
		"berserk": {
			"display_name": "Berserk",
			"description": "Maximum aggression mode"
		}
	}

	_registry.register_from_config("test_mod", config)

	assert_bool(_registry.is_valid_mode("berserk")).is_true()


func test_register_from_config_handles_multiple_modes() -> void:
	var config: Dictionary = {
		"berserk": {
			"display_name": "Berserk"
		},
		"protective": {
			"display_name": "Protective"
		},
		"sneaky": {
			"display_name": "Sneaky"
		}
	}

	_registry.register_from_config("test_mod", config)

	assert_bool(_registry.is_valid_mode("berserk")).is_true()
	assert_bool(_registry.is_valid_mode("protective")).is_true()
	assert_bool(_registry.is_valid_mode("sneaky")).is_true()


func test_register_from_config_stores_display_name() -> void:
	var config: Dictionary = {
		"berserk": {
			"display_name": "Super Berserk Mode"
		}
	}

	_registry.register_from_config("test_mod", config)

	assert_str(_registry.get_display_name("berserk")).is_equal("Super Berserk Mode")


func test_register_from_config_stores_description() -> void:
	var config: Dictionary = {
		"berserk": {
			"description": "Ignores all self-preservation instincts"
		}
	}

	_registry.register_from_config("test_mod", config)

	assert_str(_registry.get_description("berserk")).is_equal("Ignores all self-preservation instincts")


func test_register_from_config_tracks_source_mod() -> void:
	var config: Dictionary = {
		"berserk": {
			"display_name": "Berserk"
		}
	}

	_registry.register_from_config("my_awesome_mod", config)

	assert_str(_registry.get_mode_source("berserk")).is_equal("my_awesome_mod")


func test_register_from_config_skips_non_dictionary_values() -> void:
	var config: Dictionary = {
		"berserk": {
			"display_name": "Berserk"
		},
		"invalid_string": "not a dictionary",
		"invalid_number": 42,
		"invalid_array": [1, 2, 3]
	}

	_registry.register_from_config("test_mod", config)

	# Only the valid mode should be registered (plus the 3 defaults)
	var stats: Dictionary = _registry.get_stats()
	assert_int(stats.mod_mode_count).is_equal(1)
	assert_bool(_registry.is_valid_mode("berserk")).is_true()


func test_register_from_config_fallback_display_name() -> void:
	var config: Dictionary = {
		"custom_mode": {}  # No display_name provided
	}

	_registry.register_from_config("test_mod", config)

	# Should capitalize the mode ID as fallback
	assert_str(_registry.get_display_name("custom_mode")).is_equal("Custom Mode")


# =============================================================================
# VALIDATION TESTS
# =============================================================================

func test_register_mode_rejects_empty_id() -> void:
	var config: Dictionary = {
		"": {
			"display_name": "Empty ID"
		},
		"   ": {
			"display_name": "Whitespace ID"
		}
	}

	_registry.register_from_config("test_mod", config)

	# Neither should be registered
	var stats: Dictionary = _registry.get_stats()
	assert_int(stats.mod_mode_count).is_equal(0)


func test_is_valid_mode_returns_false_for_unknown() -> void:
	assert_bool(_registry.is_valid_mode("nonexistent_mode")).is_false()


# =============================================================================
# OVERRIDE BEHAVIOR TESTS
# =============================================================================

func test_later_registration_overrides_earlier() -> void:
	# First mod registers a mode
	var config1: Dictionary = {
		"berserk": {
			"display_name": "Original Berserk"
		}
	}
	_registry.register_from_config("base_mod", config1)

	# Second mod overrides it
	var config2: Dictionary = {
		"berserk": {
			"display_name": "Override Berserk"
		}
	}
	_registry.register_from_config("override_mod", config2)

	# Override should win
	assert_str(_registry.get_display_name("berserk")).is_equal("Override Berserk")
	assert_str(_registry.get_mode_source("berserk")).is_equal("override_mod")


func test_mod_can_override_default_mode() -> void:
	# A mod can override the default aggressive mode
	var config: Dictionary = {
		"aggressive": {
			"display_name": "Hyper Aggressive",
			"description": "Custom aggressive behavior"
		}
	}

	_registry.register_from_config("override_mod", config)

	assert_str(_registry.get_display_name("aggressive")).is_equal("Hyper Aggressive")
	assert_str(_registry.get_mode_source("aggressive")).is_equal("override_mod")


func test_default_mode_source_is_base() -> void:
	# Default modes should report "base" as their source
	assert_str(_registry.get_mode_source("aggressive")).is_equal("base")
	assert_str(_registry.get_mode_source("cautious")).is_equal("base")
	assert_str(_registry.get_mode_source("opportunistic")).is_equal("base")


# =============================================================================
# CASE INSENSITIVITY TESTS
# =============================================================================

func test_mode_ids_normalized_to_lowercase() -> void:
	var config: Dictionary = {
		"BERSERK": {
			"display_name": "Berserk"
		}
	}

	_registry.register_from_config("test_mod", config)

	# Should be accessible in lowercase
	assert_bool(_registry.is_valid_mode("berserk")).is_true()


func test_is_valid_mode_is_case_insensitive() -> void:
	var config: Dictionary = {
		"berserk": {
			"display_name": "Berserk"
		}
	}

	_registry.register_from_config("test_mod", config)

	assert_bool(_registry.is_valid_mode("berserk")).is_true()
	assert_bool(_registry.is_valid_mode("BERSERK")).is_true()
	assert_bool(_registry.is_valid_mode("Berserk")).is_true()
	assert_bool(_registry.is_valid_mode("BeRsErK")).is_true()


func test_get_mode_is_case_insensitive() -> void:
	var config: Dictionary = {
		"berserk": {
			"display_name": "Test Mode"
		}
	}

	_registry.register_from_config("test_mod", config)

	var lower: Dictionary = _registry.get_mode("berserk")
	var upper: Dictionary = _registry.get_mode("BERSERK")
	var mixed: Dictionary = _registry.get_mode("BeRsErK")

	assert_str(lower.get("display_name", "")).is_equal("Test Mode")
	assert_str(upper.get("display_name", "")).is_equal("Test Mode")
	assert_str(mixed.get("display_name", "")).is_equal("Test Mode")


func test_get_display_name_is_case_insensitive() -> void:
	assert_str(_registry.get_display_name("AGGRESSIVE")).is_equal("Aggressive")
	assert_str(_registry.get_display_name("Aggressive")).is_equal("Aggressive")
	assert_str(_registry.get_display_name("aggressive")).is_equal("Aggressive")


# =============================================================================
# LOOKUP API TESTS
# =============================================================================

func test_get_mode_ids_returns_sorted_array() -> void:
	var config: Dictionary = {
		"zebra_mode": {"display_name": "Zebra"},
		"alpha_mode": {"display_name": "Alpha"},
		"middle_mode": {"display_name": "Middle"}
	}

	_registry.register_from_config("test_mod", config)

	var ids: Array[String] = _registry.get_mode_ids()

	# Check sorting (defaults + custom, all alphabetically sorted)
	var prev: String = ""
	for id: String in ids:
		assert_bool(id >= prev).is_true()
		prev = id


func test_get_all_modes_returns_metadata_array() -> void:
	var config: Dictionary = {
		"berserk": {"display_name": "Berserk Mode"},
		"protective": {"display_name": "Protective Mode"}
	}

	_registry.register_from_config("test_mod", config)

	var modes: Array[Dictionary] = _registry.get_all_modes()

	# Should have 3 defaults + 2 custom = 5 modes
	assert_int(modes.size()).is_equal(5)

	# Each entry should have required fields
	for mode: Dictionary in modes:
		assert_bool("id" in mode).is_true()
		assert_bool("display_name" in mode).is_true()
		assert_bool("description" in mode).is_true()
		assert_bool("source_mod" in mode).is_true()


func test_get_all_modes_sorted_by_display_name() -> void:
	var modes: Array[Dictionary] = _registry.get_all_modes()

	var prev_name: String = ""
	for mode: Dictionary in modes:
		var name: String = mode.get("display_name", "")
		assert_bool(name >= prev_name).is_true()
		prev_name = name


func test_get_mode_returns_copy_of_metadata() -> void:
	var config: Dictionary = {
		"berserk": {
			"display_name": "Original"
		}
	}

	_registry.register_from_config("test_mod", config)

	var mode1: Dictionary = _registry.get_mode("berserk")
	var mode2: Dictionary = _registry.get_mode("berserk")

	# Modifying one should not affect the other
	mode1["display_name"] = "Modified"

	assert_str(mode2.get("display_name", "")).is_equal("Original")


func test_get_mode_returns_empty_for_unknown() -> void:
	var mode: Dictionary = _registry.get_mode("nonexistent")
	assert_bool(mode.is_empty()).is_true()


func test_get_display_name_for_unknown_capitalizes_id() -> void:
	# Godot's capitalize() converts snake_case to Title Case
	var display: String = _registry.get_display_name("some_unknown_mode")
	assert_str(display).is_equal("Some Unknown Mode")


func test_get_description_returns_empty_for_unknown() -> void:
	var description: String = _registry.get_description("nonexistent")
	assert_str(description).is_empty()


func test_get_mode_source_returns_empty_for_unknown() -> void:
	var source: String = _registry.get_mode_source("nonexistent")
	assert_str(source).is_empty()


# =============================================================================
# UNREGISTER MOD TESTS
# =============================================================================

func test_unregister_mod_removes_mod_modes() -> void:
	var config: Dictionary = {
		"berserk": {"display_name": "Berserk"},
		"protective": {"display_name": "Protective"}
	}

	_registry.register_from_config("test_mod", config)

	assert_bool(_registry.is_valid_mode("berserk")).is_true()
	assert_bool(_registry.is_valid_mode("protective")).is_true()

	_registry.unregister_mod("test_mod")

	assert_bool(_registry.is_valid_mode("berserk")).is_false()
	assert_bool(_registry.is_valid_mode("protective")).is_false()


func test_unregister_mod_preserves_other_mod_modes() -> void:
	var config1: Dictionary = {
		"berserk": {"display_name": "Berserk"}
	}
	var config2: Dictionary = {
		"protective": {"display_name": "Protective"}
	}

	_registry.register_from_config("mod_a", config1)
	_registry.register_from_config("mod_b", config2)

	_registry.unregister_mod("mod_a")

	assert_bool(_registry.is_valid_mode("berserk")).is_false()
	assert_bool(_registry.is_valid_mode("protective")).is_true()


func test_unregister_mod_preserves_default_modes() -> void:
	var config: Dictionary = {
		"berserk": {"display_name": "Berserk"}
	}

	_registry.register_from_config("test_mod", config)
	_registry.unregister_mod("test_mod")

	# Default modes should still be present
	assert_bool(_registry.is_valid_mode("aggressive")).is_true()
	assert_bool(_registry.is_valid_mode("cautious")).is_true()
	assert_bool(_registry.is_valid_mode("opportunistic")).is_true()


# =============================================================================
# SIGNAL TESTS
# =============================================================================

func test_register_from_config_emits_signal() -> void:
	_tracker.track(_registry.registrations_changed)

	var config: Dictionary = {
		"berserk": {"display_name": "Berserk"}
	}

	_registry.register_from_config("test_mod", config)

	assert_bool(_tracker.was_emitted("registrations_changed")).is_true()


func test_clear_mod_registrations_emits_signal() -> void:
	# First add some modes
	var config: Dictionary = {
		"berserk": {"display_name": "Berserk"}
	}
	_registry.register_from_config("test_mod", config)

	_tracker.clear_emissions()
	_tracker.track(_registry.registrations_changed)

	_registry.clear_mod_registrations()

	assert_bool(_tracker.was_emitted("registrations_changed")).is_true()


func test_unregister_mod_emits_signal_when_changes_made() -> void:
	var config: Dictionary = {
		"berserk": {"display_name": "Berserk"}
	}
	_registry.register_from_config("test_mod", config)

	_tracker.clear_emissions()
	_tracker.track(_registry.registrations_changed)

	_registry.unregister_mod("test_mod")

	assert_bool(_tracker.was_emitted("registrations_changed")).is_true()


# =============================================================================
# UTILITY FUNCTION TESTS
# =============================================================================

func test_clear_mod_registrations_removes_all_mod_modes() -> void:
	var config: Dictionary = {
		"berserk": {"display_name": "Berserk"},
		"protective": {"display_name": "Protective"}
	}

	_registry.register_from_config("test_mod", config)

	var before_stats: Dictionary = _registry.get_stats()
	assert_int(before_stats.mod_mode_count).is_equal(2)

	_registry.clear_mod_registrations()

	var after_stats: Dictionary = _registry.get_stats()
	assert_int(after_stats.mod_mode_count).is_equal(0)


func test_clear_mod_registrations_preserves_defaults() -> void:
	var config: Dictionary = {
		"berserk": {"display_name": "Berserk"}
	}

	_registry.register_from_config("test_mod", config)
	_registry.clear_mod_registrations()

	# Defaults should still be present
	var stats: Dictionary = _registry.get_stats()
	assert_int(stats.mode_count).is_equal(3)  # 3 defaults

	assert_bool(_registry.is_valid_mode("aggressive")).is_true()
	assert_bool(_registry.is_valid_mode("cautious")).is_true()
	assert_bool(_registry.is_valid_mode("opportunistic")).is_true()


func test_get_stats_returns_accurate_counts() -> void:
	var config: Dictionary = {
		"berserk": {"display_name": "Berserk"},
		"protective": {"display_name": "Protective"},
		"sneaky": {"display_name": "Sneaky"}
	}

	_registry.register_from_config("test_mod", config)

	var stats: Dictionary = _registry.get_stats()

	# 3 defaults + 3 mod modes = 6 total
	assert_int(stats.get("mode_count", 0)).is_equal(6)
	assert_int(stats.get("mod_mode_count", 0)).is_equal(3)


func test_get_stats_on_empty_registry() -> void:
	# Fresh registry with only defaults
	var stats: Dictionary = _registry.get_stats()

	assert_int(stats.get("mode_count", -1)).is_equal(3)  # 3 defaults
	assert_int(stats.get("mod_mode_count", -1)).is_equal(0)


# =============================================================================
# CACHE BEHAVIOR TESTS
# =============================================================================

func test_cache_rebuild_after_registration() -> void:
	# Access modes before registration (builds cache)
	var initial_ids: Array[String] = _registry.get_mode_ids()
	assert_int(initial_ids.size()).is_equal(3)

	# Register new mode
	var config: Dictionary = {
		"berserk": {"display_name": "Berserk"}
	}
	_registry.register_from_config("test_mod", config)

	# Cache should be dirty and rebuilt on next access
	var updated_ids: Array[String] = _registry.get_mode_ids()
	assert_int(updated_ids.size()).is_equal(4)
	assert_bool("berserk" in updated_ids).is_true()


func test_cache_rebuild_after_unregister() -> void:
	var config: Dictionary = {
		"berserk": {"display_name": "Berserk"}
	}
	_registry.register_from_config("test_mod", config)

	# Access to build cache
	var initial_ids: Array[String] = _registry.get_mode_ids()
	assert_int(initial_ids.size()).is_equal(4)

	# Unregister
	_registry.unregister_mod("test_mod")

	# Cache should be rebuilt
	var updated_ids: Array[String] = _registry.get_mode_ids()
	assert_int(updated_ids.size()).is_equal(3)
	assert_bool("berserk" not in updated_ids).is_true()
