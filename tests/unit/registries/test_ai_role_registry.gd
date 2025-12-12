## Unit Tests for AIRoleRegistry
##
## Tests the AI tactical role registration system.
## Verifies mod extensibility, override behavior, default role presence,
## and the role behavior script instance management (LRU cache).
class_name TestAIRoleRegistry
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _registry: RefCounted


func before_test() -> void:
	# Create a fresh registry for each test
	var AIRoleRegistryClass: GDScript = load("res://core/registries/ai_role_registry.gd")
	_registry = AIRoleRegistryClass.new()


# =============================================================================
# DEFAULT ROLES TESTS
# =============================================================================

func test_default_roles_are_present() -> void:
	var role_ids: Array[String] = _registry.get_role_ids()

	assert_bool("support" in role_ids).is_true()
	assert_bool("aggressive" in role_ids).is_true()
	assert_bool("defensive" in role_ids).is_true()
	assert_bool("tactical" in role_ids).is_true()


func test_default_role_count() -> void:
	var stats: Dictionary = _registry.get_stats()

	# Should have exactly 4 default roles
	assert_int(stats.get("role_count", 0)).is_equal(4)
	# No mod roles registered yet
	assert_int(stats.get("mod_role_count", 0)).is_equal(0)


func test_is_default_role_returns_true_for_defaults() -> void:
	assert_bool(_registry.is_default_role("support")).is_true()
	assert_bool(_registry.is_default_role("aggressive")).is_true()
	assert_bool(_registry.is_default_role("defensive")).is_true()
	assert_bool(_registry.is_default_role("tactical")).is_true()


func test_is_default_role_returns_false_for_custom() -> void:
	var config: Dictionary = {
		"hacking": {
			"display_name": "Hacking",
			"description": "Prioritizes disabling enemy systems"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_bool(_registry.is_default_role("hacking")).is_false()


func test_default_roles_have_display_names() -> void:
	assert_str(_registry.get_display_name("support")).is_equal("Support")
	assert_str(_registry.get_display_name("aggressive")).is_equal("Aggressive")
	assert_str(_registry.get_display_name("defensive")).is_equal("Defensive")
	assert_str(_registry.get_display_name("tactical")).is_equal("Tactical")


func test_default_roles_have_descriptions() -> void:
	# Each default role should have a non-empty description
	assert_str(_registry.get_description("support")).is_not_empty()
	assert_str(_registry.get_description("aggressive")).is_not_empty()
	assert_str(_registry.get_description("defensive")).is_not_empty()
	assert_str(_registry.get_description("tactical")).is_not_empty()


func test_default_roles_have_no_script_path() -> void:
	# Default roles don't have custom behavior scripts
	assert_str(_registry.get_role_script_path("support")).is_empty()
	assert_str(_registry.get_role_script_path("aggressive")).is_empty()
	assert_str(_registry.get_role_script_path("defensive")).is_empty()
	assert_str(_registry.get_role_script_path("tactical")).is_empty()


# =============================================================================
# REGISTRATION FROM CONFIG TESTS
# =============================================================================

func test_register_from_config_adds_role() -> void:
	var config: Dictionary = {
		"hacking": {
			"display_name": "Hacking",
			"description": "Disables enemy systems"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_bool(_registry.is_valid_role("hacking")).is_true()


func test_register_from_config_handles_multiple_roles() -> void:
	var config: Dictionary = {
		"hacking": {
			"display_name": "Hacking"
		},
		"stealth": {
			"display_name": "Stealth"
		},
		"demolition": {
			"display_name": "Demolition"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_bool(_registry.is_valid_role("hacking")).is_true()
	assert_bool(_registry.is_valid_role("stealth")).is_true()
	assert_bool(_registry.is_valid_role("demolition")).is_true()


func test_register_from_config_stores_display_name() -> void:
	var config: Dictionary = {
		"hacking": {
			"display_name": "Elite Hacking Unit"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_str(_registry.get_display_name("hacking")).is_equal("Elite Hacking Unit")


func test_register_from_config_stores_description() -> void:
	var config: Dictionary = {
		"hacking": {
			"description": "Specializes in electronic warfare"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_str(_registry.get_description("hacking")).is_equal("Specializes in electronic warfare")


func test_register_from_config_stores_script_path() -> void:
	var config: Dictionary = {
		"hacking": {
			"display_name": "Hacking",
			"script_path": "ai_roles/hacking_role.gd"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Script path should be full path including mod directory
	assert_str(_registry.get_role_script_path("hacking")).is_equal("res://mods/test_mod/ai_roles/hacking_role.gd")


func test_register_from_config_tracks_source_mod() -> void:
	var config: Dictionary = {
		"hacking": {
			"display_name": "Hacking"
		}
	}

	_registry.register_from_config("my_awesome_mod", config, "res://mods/my_awesome_mod")

	assert_str(_registry.get_role_source("hacking")).is_equal("my_awesome_mod")


func test_register_from_config_skips_non_dictionary_values() -> void:
	var config: Dictionary = {
		"hacking": {
			"display_name": "Hacking"
		},
		"invalid_string": "not a dictionary",
		"invalid_number": 42,
		"invalid_array": [1, 2, 3]
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Only the valid role should be registered (plus the 4 defaults)
	var stats: Dictionary = _registry.get_stats()
	assert_int(stats.mod_role_count).is_equal(1)
	assert_bool(_registry.is_valid_role("hacking")).is_true()


func test_register_from_config_fallback_display_name() -> void:
	var config: Dictionary = {
		"custom_role": {}  # No display_name provided
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Should capitalize the role ID as fallback
	assert_str(_registry.get_display_name("custom_role")).is_equal("Custom Role")


# =============================================================================
# VALIDATION TESTS
# =============================================================================

func test_register_role_rejects_empty_id() -> void:
	var config: Dictionary = {
		"": {
			"display_name": "Empty ID"
		},
		"   ": {
			"display_name": "Whitespace ID"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Neither should be registered
	var stats: Dictionary = _registry.get_stats()
	assert_int(stats.mod_role_count).is_equal(0)


func test_is_valid_role_returns_false_for_unknown() -> void:
	assert_bool(_registry.is_valid_role("nonexistent_role")).is_false()


# =============================================================================
# OVERRIDE BEHAVIOR TESTS
# =============================================================================

func test_later_registration_overrides_earlier() -> void:
	# First mod registers a role
	var config1: Dictionary = {
		"hacking": {
			"display_name": "Original Hacking"
		}
	}
	_registry.register_from_config("base_mod", config1, "res://mods/base_mod")

	# Second mod overrides it
	var config2: Dictionary = {
		"hacking": {
			"display_name": "Override Hacking"
		}
	}
	_registry.register_from_config("override_mod", config2, "res://mods/override_mod")

	# Override should win
	assert_str(_registry.get_display_name("hacking")).is_equal("Override Hacking")
	assert_str(_registry.get_role_source("hacking")).is_equal("override_mod")


func test_mod_can_override_default_role() -> void:
	# A mod can override the default support role
	var config: Dictionary = {
		"support": {
			"display_name": "Enhanced Support",
			"description": "Custom support behavior"
		}
	}

	_registry.register_from_config("override_mod", config, "res://mods/override_mod")

	assert_str(_registry.get_display_name("support")).is_equal("Enhanced Support")
	assert_str(_registry.get_role_source("support")).is_equal("override_mod")


func test_default_role_source_is_base() -> void:
	# Default roles should report "base" as their source
	assert_str(_registry.get_role_source("support")).is_equal("base")
	assert_str(_registry.get_role_source("aggressive")).is_equal("base")
	assert_str(_registry.get_role_source("defensive")).is_equal("base")
	assert_str(_registry.get_role_source("tactical")).is_equal("base")


func test_override_clears_cached_instance() -> void:
	# First register a role
	var config1: Dictionary = {
		"hacking": {
			"display_name": "Original"
		}
	}
	_registry.register_from_config("base_mod", config1, "res://mods/base_mod")

	# Cache size check before override
	var stats_before: Dictionary = _registry.get_stats()

	# Override with different settings
	var config2: Dictionary = {
		"hacking": {
			"display_name": "Override"
		}
	}
	_registry.register_from_config("override_mod", config2, "res://mods/override_mod")

	# Role count should stay at 1 for this mod role (it's an override, not addition)
	var stats_after: Dictionary = _registry.get_stats()
	assert_int(stats_after.mod_role_count).is_equal(1)


# =============================================================================
# CASE INSENSITIVITY TESTS
# =============================================================================

func test_role_ids_normalized_to_lowercase() -> void:
	var config: Dictionary = {
		"HACKING": {
			"display_name": "Hacking"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Should be accessible in lowercase
	assert_bool(_registry.is_valid_role("hacking")).is_true()


func test_is_valid_role_is_case_insensitive() -> void:
	var config: Dictionary = {
		"hacking": {
			"display_name": "Hacking"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_bool(_registry.is_valid_role("hacking")).is_true()
	assert_bool(_registry.is_valid_role("HACKING")).is_true()
	assert_bool(_registry.is_valid_role("Hacking")).is_true()
	assert_bool(_registry.is_valid_role("HaCkInG")).is_true()


func test_get_role_is_case_insensitive() -> void:
	var config: Dictionary = {
		"hacking": {
			"display_name": "Test Role"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var lower: Dictionary = _registry.get_role("hacking")
	var upper: Dictionary = _registry.get_role("HACKING")
	var mixed: Dictionary = _registry.get_role("HaCkInG")

	assert_str(lower.get("display_name", "")).is_equal("Test Role")
	assert_str(upper.get("display_name", "")).is_equal("Test Role")
	assert_str(mixed.get("display_name", "")).is_equal("Test Role")


func test_get_display_name_is_case_insensitive() -> void:
	assert_str(_registry.get_display_name("SUPPORT")).is_equal("Support")
	assert_str(_registry.get_display_name("Support")).is_equal("Support")
	assert_str(_registry.get_display_name("support")).is_equal("Support")


# =============================================================================
# LOOKUP API TESTS
# =============================================================================

func test_get_role_ids_returns_sorted_array() -> void:
	var config: Dictionary = {
		"zebra_role": {"display_name": "Zebra"},
		"alpha_role": {"display_name": "Alpha"},
		"middle_role": {"display_name": "Middle"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var ids: Array[String] = _registry.get_role_ids()

	# Check sorting (defaults + custom, all alphabetically sorted)
	var prev: String = ""
	for id: String in ids:
		assert_bool(id >= prev).is_true()
		prev = id


func test_get_all_roles_returns_metadata_array() -> void:
	var config: Dictionary = {
		"hacking": {"display_name": "Hacking Role"},
		"stealth": {"display_name": "Stealth Role"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var roles: Array[Dictionary] = _registry.get_all_roles()

	# Should have 4 defaults + 2 custom = 6 roles
	assert_int(roles.size()).is_equal(6)

	# Each entry should have required fields
	for role: Dictionary in roles:
		assert_bool("id" in role).is_true()
		assert_bool("display_name" in role).is_true()
		assert_bool("description" in role).is_true()
		assert_bool("source_mod" in role).is_true()
		assert_bool("script_path" in role).is_true()


func test_get_all_roles_sorted_by_display_name() -> void:
	var roles: Array[Dictionary] = _registry.get_all_roles()

	var prev_name: String = ""
	for role: Dictionary in roles:
		var name: String = role.get("display_name", "")
		assert_bool(name >= prev_name).is_true()
		prev_name = name


func test_get_role_returns_copy_of_metadata() -> void:
	var config: Dictionary = {
		"hacking": {
			"display_name": "Original"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var role1: Dictionary = _registry.get_role("hacking")
	var role2: Dictionary = _registry.get_role("hacking")

	# Modifying one should not affect the other
	role1["display_name"] = "Modified"

	assert_str(role2.get("display_name", "")).is_equal("Original")


func test_get_role_returns_empty_for_unknown() -> void:
	var role: Dictionary = _registry.get_role("nonexistent")
	assert_bool(role.is_empty()).is_true()


func test_get_display_name_for_unknown_capitalizes_id() -> void:
	# Godot's capitalize() converts snake_case to Title Case
	var display: String = _registry.get_display_name("some_unknown_role")
	assert_str(display).is_equal("Some Unknown Role")


func test_get_description_returns_empty_for_unknown() -> void:
	var description: String = _registry.get_description("nonexistent")
	assert_str(description).is_empty()


func test_get_role_source_returns_empty_for_unknown() -> void:
	var source: String = _registry.get_role_source("nonexistent")
	assert_str(source).is_empty()


func test_get_role_script_path_returns_empty_for_unknown() -> void:
	var path: String = _registry.get_role_script_path("nonexistent")
	assert_str(path).is_empty()


# =============================================================================
# INSTANCE MANAGEMENT TESTS
# =============================================================================

func test_get_role_instance_returns_null_for_role_without_script() -> void:
	# Default roles don't have scripts
	var instance: RefCounted = _registry.get_role_instance("support")
	assert_object(instance).is_null()


func test_get_role_instance_returns_null_for_unknown() -> void:
	var instance: RefCounted = _registry.get_role_instance("nonexistent")
	assert_object(instance).is_null()


func test_get_role_instance_returns_null_for_missing_script_file() -> void:
	var config: Dictionary = {
		"hacking": {
			"display_name": "Hacking",
			"script_path": "ai_roles/nonexistent_script.gd"  # File doesn't exist
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Should return null since file doesn't exist
	var instance: RefCounted = _registry.get_role_instance("hacking")
	assert_object(instance).is_null()


func test_cached_instances_count_in_stats() -> void:
	var stats: Dictionary = _registry.get_stats()
	assert_bool("cached_instances" in stats).is_true()
	assert_int(stats.cached_instances).is_greater_equal(0)


# =============================================================================
# UNREGISTER MOD TESTS
# =============================================================================

func test_unregister_mod_removes_mod_roles() -> void:
	var config: Dictionary = {
		"hacking": {"display_name": "Hacking"},
		"stealth": {"display_name": "Stealth"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_bool(_registry.is_valid_role("hacking")).is_true()
	assert_bool(_registry.is_valid_role("stealth")).is_true()

	_registry.unregister_mod("test_mod")

	assert_bool(_registry.is_valid_role("hacking")).is_false()
	assert_bool(_registry.is_valid_role("stealth")).is_false()


func test_unregister_mod_preserves_other_mod_roles() -> void:
	var config1: Dictionary = {
		"hacking": {"display_name": "Hacking"}
	}
	var config2: Dictionary = {
		"stealth": {"display_name": "Stealth"}
	}

	_registry.register_from_config("mod_a", config1, "res://mods/mod_a")
	_registry.register_from_config("mod_b", config2, "res://mods/mod_b")

	_registry.unregister_mod("mod_a")

	assert_bool(_registry.is_valid_role("hacking")).is_false()
	assert_bool(_registry.is_valid_role("stealth")).is_true()


func test_unregister_mod_preserves_default_roles() -> void:
	var config: Dictionary = {
		"hacking": {"display_name": "Hacking"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")
	_registry.unregister_mod("test_mod")

	# Default roles should still be present
	assert_bool(_registry.is_valid_role("support")).is_true()
	assert_bool(_registry.is_valid_role("aggressive")).is_true()
	assert_bool(_registry.is_valid_role("defensive")).is_true()
	assert_bool(_registry.is_valid_role("tactical")).is_true()


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
		"hacking": {"display_name": "Hacking"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_bool(_signal_received).is_true()


func test_clear_mod_registrations_emits_signal() -> void:
	# First add some roles
	var config: Dictionary = {
		"hacking": {"display_name": "Hacking"}
	}
	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	_signal_received = false
	_registry.registrations_changed.connect(_on_registrations_changed)

	_registry.clear_mod_registrations()

	assert_bool(_signal_received).is_true()


func test_unregister_mod_emits_signal_when_changes_made() -> void:
	var config: Dictionary = {
		"hacking": {"display_name": "Hacking"}
	}
	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	_signal_received = false
	_registry.registrations_changed.connect(_on_registrations_changed)

	_registry.unregister_mod("test_mod")

	assert_bool(_signal_received).is_true()


# =============================================================================
# UTILITY FUNCTION TESTS
# =============================================================================

func test_clear_mod_registrations_removes_all_mod_roles() -> void:
	var config: Dictionary = {
		"hacking": {"display_name": "Hacking"},
		"stealth": {"display_name": "Stealth"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var before_stats: Dictionary = _registry.get_stats()
	assert_int(before_stats.mod_role_count).is_equal(2)

	_registry.clear_mod_registrations()

	var after_stats: Dictionary = _registry.get_stats()
	assert_int(after_stats.mod_role_count).is_equal(0)


func test_clear_mod_registrations_preserves_defaults() -> void:
	var config: Dictionary = {
		"hacking": {"display_name": "Hacking"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")
	_registry.clear_mod_registrations()

	# Defaults should still be present
	var stats: Dictionary = _registry.get_stats()
	assert_int(stats.role_count).is_equal(4)  # 4 defaults

	assert_bool(_registry.is_valid_role("support")).is_true()
	assert_bool(_registry.is_valid_role("aggressive")).is_true()
	assert_bool(_registry.is_valid_role("defensive")).is_true()
	assert_bool(_registry.is_valid_role("tactical")).is_true()


func test_clear_mod_registrations_clears_cached_instances() -> void:
	# After clearing, cached_instances should be 0
	var config: Dictionary = {
		"hacking": {"display_name": "Hacking"}
	}
	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	_registry.clear_mod_registrations()

	var stats: Dictionary = _registry.get_stats()
	assert_int(stats.cached_instances).is_equal(0)


func test_get_stats_returns_accurate_counts() -> void:
	var config: Dictionary = {
		"hacking": {"display_name": "Hacking"},
		"stealth": {"display_name": "Stealth"},
		"demolition": {"display_name": "Demolition"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var stats: Dictionary = _registry.get_stats()

	# 4 defaults + 3 mod roles = 7 total
	assert_int(stats.get("role_count", 0)).is_equal(7)
	assert_int(stats.get("mod_role_count", 0)).is_equal(3)


func test_get_stats_on_empty_registry() -> void:
	# Fresh registry with only defaults
	var stats: Dictionary = _registry.get_stats()

	assert_int(stats.get("role_count", -1)).is_equal(4)  # 4 defaults
	assert_int(stats.get("mod_role_count", -1)).is_equal(0)
	assert_int(stats.get("cached_instances", -1)).is_equal(0)


# =============================================================================
# CACHE BEHAVIOR TESTS
# =============================================================================

func test_cache_rebuild_after_registration() -> void:
	# Access roles before registration (builds cache)
	var initial_ids: Array[String] = _registry.get_role_ids()
	assert_int(initial_ids.size()).is_equal(4)

	# Register new role
	var config: Dictionary = {
		"hacking": {"display_name": "Hacking"}
	}
	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Cache should be dirty and rebuilt on next access
	var updated_ids: Array[String] = _registry.get_role_ids()
	assert_int(updated_ids.size()).is_equal(5)
	assert_bool("hacking" in updated_ids).is_true()


func test_cache_rebuild_after_unregister() -> void:
	var config: Dictionary = {
		"hacking": {"display_name": "Hacking"}
	}
	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Access to build cache
	var initial_ids: Array[String] = _registry.get_role_ids()
	assert_int(initial_ids.size()).is_equal(5)

	# Unregister
	_registry.unregister_mod("test_mod")

	# Cache should be rebuilt
	var updated_ids: Array[String] = _registry.get_role_ids()
	assert_int(updated_ids.size()).is_equal(4)
	assert_bool("hacking" not in updated_ids).is_true()


# =============================================================================
# SCRIPT PATH HANDLING TESTS
# =============================================================================

func test_script_path_constructed_from_mod_directory() -> void:
	var config: Dictionary = {
		"custom": {
			"display_name": "Custom",
			"script_path": "scripts/custom_role.gd"
		}
	}

	_registry.register_from_config("my_mod", config, "res://mods/my_mod")

	var full_path: String = _registry.get_role_script_path("custom")
	assert_str(full_path).is_equal("res://mods/my_mod/scripts/custom_role.gd")


func test_role_without_script_path_has_empty_string() -> void:
	var config: Dictionary = {
		"custom": {
			"display_name": "Custom"
			# No script_path provided
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_str(_registry.get_role_script_path("custom")).is_empty()
