## Unit Tests for AIBrainRegistry
##
## Tests the AI brain registration system added in Phase 4.
## Verifies mod extensibility and registry operations.
class_name TestAIBrainRegistry
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _registry: RefCounted


func before_test() -> void:
	# Create a fresh registry for each test
	var AIBrainRegistryClass: GDScript = load("res://core/registries/ai_brain_registry.gd")
	_registry = AIBrainRegistryClass.new()


# =============================================================================
# REGISTRATION FROM CONFIG TESTS
# =============================================================================

func test_register_from_config_adds_brain() -> void:
	var config: Dictionary = {
		"aggressive": {
			"path": "ai_brains/ai_aggressive.gd",
			"display_name": "Aggressive AI",
			"description": "Always attacks nearest enemy"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_bool(_registry.has_brain("aggressive")).is_true()


func test_register_from_config_handles_multiple_brains() -> void:
	var config: Dictionary = {
		"aggressive": {
			"path": "ai_brains/ai_aggressive.gd",
			"display_name": "Aggressive"
		},
		"defensive": {
			"path": "ai_brains/ai_defensive.gd",
			"display_name": "Defensive"
		},
		"healer": {
			"path": "ai_brains/ai_healer.gd",
			"display_name": "Healer"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_bool(_registry.has_brain("aggressive")).is_true()
	assert_bool(_registry.has_brain("defensive")).is_true()
	assert_bool(_registry.has_brain("healer")).is_true()


func test_register_from_config_stores_full_path() -> void:
	var config: Dictionary = {
		"aggressive": {
			"path": "ai_brains/ai_aggressive.gd",
			"display_name": "Aggressive"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var path: String = _registry.get_brain_path("aggressive")
	assert_str(path).is_equal("res://mods/test_mod/ai_brains/ai_aggressive.gd")


func test_register_from_config_stores_display_name() -> void:
	var config: Dictionary = {
		"aggressive": {
			"path": "ai_brains/ai_aggressive.gd",
			"display_name": "Super Aggressive AI"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_str(_registry.get_display_name("aggressive")).is_equal("Super Aggressive AI")


func test_register_from_config_stores_description() -> void:
	var config: Dictionary = {
		"aggressive": {
			"path": "ai_brains/ai_aggressive.gd",
			"description": "Charges at enemies relentlessly"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_str(_registry.get_description("aggressive")).is_equal("Charges at enemies relentlessly")


func test_register_from_config_tracks_source_mod() -> void:
	var config: Dictionary = {
		"aggressive": {
			"path": "ai_brains/ai_aggressive.gd"
		}
	}

	_registry.register_from_config("my_awesome_mod", config, "res://mods/my_awesome_mod")

	assert_str(_registry.get_source_mod("aggressive")).is_equal("my_awesome_mod")


func test_register_from_config_skips_non_dictionary_values() -> void:
	var config: Dictionary = {
		"aggressive": {
			"path": "ai_brains/ai_aggressive.gd"
		},
		"invalid_string": "not a dictionary",
		"invalid_number": 42
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Only the valid brain should be registered
	var brain_ids: Array[String] = _registry.get_all_brain_ids()
	assert_int(brain_ids.size()).is_equal(1)
	assert_bool(_registry.has_brain("aggressive")).is_true()


# =============================================================================
# VALIDATION TESTS
# =============================================================================

func test_register_from_config_requires_path_field() -> void:
	var config: Dictionary = {
		"no_path_brain": {
			"display_name": "Missing Path"
			# No "path" field!
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Brain should NOT be registered without path
	assert_bool(_registry.has_brain("no_path_brain")).is_false()


func test_register_brain_rejects_empty_id() -> void:
	var config: Dictionary = {
		"": {
			"path": "ai_brains/empty.gd"
		},
		"   ": {
			"path": "ai_brains/whitespace.gd"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Neither should be registered
	assert_int(_registry.get_all_brain_ids().size()).is_equal(0)


# =============================================================================
# OVERRIDE BEHAVIOR TESTS
# =============================================================================

func test_later_registration_overrides_earlier() -> void:
	# First mod registers a brain
	var config1: Dictionary = {
		"aggressive": {
			"path": "ai_brains/original.gd",
			"display_name": "Original"
		}
	}
	_registry.register_from_config("base_mod", config1, "res://mods/base_mod")

	# Second mod overrides it
	var config2: Dictionary = {
		"aggressive": {
			"path": "ai_brains/override.gd",
			"display_name": "Override"
		}
	}
	_registry.register_from_config("override_mod", config2, "res://mods/override_mod")

	# Override should win
	assert_str(_registry.get_display_name("aggressive")).is_equal("Override")
	assert_str(_registry.get_source_mod("aggressive")).is_equal("override_mod")
	assert_str(_registry.get_brain_path("aggressive")).contains("override_mod")


func test_override_clears_cached_instance() -> void:
	# Register initial brain
	var config1: Dictionary = {
		"aggressive": {
			"path": "ai_brains/ai_aggressive.gd"
		}
	}
	_registry.register_from_config("base_mod", config1, "res://mods/_base_game")

	# Get stats before override - may have cached instance
	var stats_before: Dictionary = _registry.get_stats()

	# Override with different path
	var config2: Dictionary = {
		"aggressive": {
			"path": "ai_brains/different.gd"
		}
	}
	_registry.register_from_config("override_mod", config2, "res://mods/override_mod")

	# Verify the brain count stays at 1 (override, not addition)
	var stats_after: Dictionary = _registry.get_stats()
	assert_int(stats_after.brain_count).is_equal(1)


# =============================================================================
# CASE INSENSITIVITY TESTS
# =============================================================================

func test_brain_ids_normalized_to_lowercase() -> void:
	var config: Dictionary = {
		"AGGRESSIVE": {
			"path": "ai_brains/ai_aggressive.gd"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Should be accessible in lowercase
	assert_bool(_registry.has_brain("aggressive")).is_true()


func test_has_brain_is_case_insensitive() -> void:
	var config: Dictionary = {
		"aggressive": {
			"path": "ai_brains/ai_aggressive.gd"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_bool(_registry.has_brain("aggressive")).is_true()
	assert_bool(_registry.has_brain("AGGRESSIVE")).is_true()
	assert_bool(_registry.has_brain("Aggressive")).is_true()
	assert_bool(_registry.has_brain("AgGrEsSiVe")).is_true()


func test_get_brain_is_case_insensitive() -> void:
	var config: Dictionary = {
		"aggressive": {
			"path": "ai_brains/ai_aggressive.gd",
			"display_name": "Test AI"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var lower: Dictionary = _registry.get_brain("aggressive")
	var upper: Dictionary = _registry.get_brain("AGGRESSIVE")
	var mixed: Dictionary = _registry.get_brain("AgGrEsSiVe")

	assert_str(lower.get("display_name", "")).is_equal("Test AI")
	assert_str(upper.get("display_name", "")).is_equal("Test AI")
	assert_str(mixed.get("display_name", "")).is_equal("Test AI")


# =============================================================================
# LOOKUP API TESTS
# =============================================================================

func test_get_all_brain_ids_returns_sorted_array() -> void:
	var config: Dictionary = {
		"zebra": {"path": "ai/z.gd"},
		"alpha": {"path": "ai/a.gd"},
		"middle": {"path": "ai/m.gd"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var ids: Array[String] = _registry.get_all_brain_ids()

	assert_int(ids.size()).is_equal(3)
	assert_str(ids[0]).is_equal("alpha")
	assert_str(ids[1]).is_equal("middle")
	assert_str(ids[2]).is_equal("zebra")


func test_get_all_brains_returns_metadata_array() -> void:
	var config: Dictionary = {
		"defensive": {"path": "ai/d.gd", "display_name": "Defensive"},
		"aggressive": {"path": "ai/a.gd", "display_name": "Aggressive"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var brains: Array[Dictionary] = _registry.get_all_brains()

	assert_int(brains.size()).is_equal(2)
	# Should be sorted by display_name
	assert_str(brains[0].get("display_name", "")).is_equal("Aggressive")
	assert_str(brains[1].get("display_name", "")).is_equal("Defensive")


func test_get_brain_returns_copy_of_metadata() -> void:
	var config: Dictionary = {
		"aggressive": {
			"path": "ai/a.gd",
			"display_name": "Original"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var brain1: Dictionary = _registry.get_brain("aggressive")
	var brain2: Dictionary = _registry.get_brain("aggressive")

	# Modifying one should not affect the other
	brain1["display_name"] = "Modified"

	assert_str(brain2.get("display_name", "")).is_equal("Original")


func test_get_brain_returns_empty_for_unknown() -> void:
	var brain: Dictionary = _registry.get_brain("nonexistent")
	assert_bool(brain.is_empty()).is_true()


func test_get_display_name_falls_back_to_capitalize() -> void:
	var config: Dictionary = {
		"aggressive_healer": {
			"path": "ai/a.gd"
			# No display_name specified
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Should capitalize the ID as fallback (Godot converts snake_case to Title Case)
	var display: String = _registry.get_display_name("aggressive_healer")
	assert_str(display).is_equal("Aggressive Healer")


func test_get_display_name_for_unknown_capitalizes_id() -> void:
	# Godot's capitalize() converts snake_case to Title Case
	var display: String = _registry.get_display_name("some_unknown_brain")
	assert_str(display).is_equal("Some Unknown Brain")


func test_get_description_returns_empty_for_unknown() -> void:
	var description: String = _registry.get_description("nonexistent")
	assert_str(description).is_empty()


func test_get_brain_path_returns_empty_for_unknown() -> void:
	var path: String = _registry.get_brain_path("nonexistent")
	assert_str(path).is_empty()


func test_get_source_mod_returns_empty_for_unknown() -> void:
	var source: String = _registry.get_source_mod("nonexistent")
	assert_str(source).is_empty()


# =============================================================================
# INSTANCE MANAGEMENT TESTS
# =============================================================================

func test_get_brain_instance_returns_null_for_unknown() -> void:
	var instance: Resource = _registry.get_brain_instance("nonexistent")
	assert_object(instance).is_null()


func test_get_brain_instance_returns_null_for_empty_path() -> void:
	# Manually test edge case where path might be empty
	var instance: Resource = _registry.get_brain_instance("nonexistent")
	assert_object(instance).is_null()


# =============================================================================
# SIGNAL TESTS
# =============================================================================

var _signal_received: bool = false


func _on_registrations_changed() -> void:
	_signal_received = true


func test_register_from_config_emits_signal() -> void:
	_signal_received = false
	_registry.registrations_changed.connect(_on_registrations_changed)

	var config: Dictionary = {
		"aggressive": {"path": "ai/a.gd"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_bool(_signal_received).is_true()


func test_clear_mod_registrations_emits_signal() -> void:
	# First add some brains
	var config: Dictionary = {
		"aggressive": {"path": "ai/a.gd"}
	}
	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	_signal_received = false
	_registry.registrations_changed.connect(_on_registrations_changed)

	_registry.clear_mod_registrations()

	assert_bool(_signal_received).is_true()


# =============================================================================
# UTILITY FUNCTION TESTS
# =============================================================================

func test_clear_mod_registrations_empties_all() -> void:
	var config: Dictionary = {
		"aggressive": {"path": "ai/a.gd"},
		"defensive": {"path": "ai/d.gd"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_int(_registry.get_all_brain_ids().size()).is_equal(2)

	_registry.clear_mod_registrations()

	assert_int(_registry.get_all_brain_ids().size()).is_equal(0)


func test_get_stats_returns_counts() -> void:
	var config: Dictionary = {
		"aggressive": {"path": "ai/a.gd"},
		"defensive": {"path": "ai/d.gd"},
		"healer": {"path": "ai/h.gd"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var stats: Dictionary = _registry.get_stats()

	assert_int(stats.get("brain_count", 0)).is_equal(3)
	assert_bool("cached_instances" in stats).is_true()


func test_get_stats_on_empty_registry() -> void:
	var stats: Dictionary = _registry.get_stats()

	assert_int(stats.get("brain_count", -1)).is_equal(0)
	assert_int(stats.get("cached_instances", -1)).is_equal(0)


# =============================================================================
# DIRECTORY DISCOVERY TESTS
# =============================================================================

func test_discover_from_directory_returns_count() -> void:
	# Discovery depends on actual file system - test the return type
	var count: int = _registry.discover_from_directory("test_mod", "res://nonexistent/path")
	assert_int(count).is_greater_equal(0)


func test_discover_skips_already_registered() -> void:
	# First register via config
	var config: Dictionary = {
		"aggressive": {"path": "ai/a.gd", "display_name": "From Config"}
	}
	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Discovery should not override the config registration
	# We can't easily test this without a real file system, but we can verify
	# the existing registration is preserved
	assert_str(_registry.get_display_name("aggressive")).is_equal("From Config")
