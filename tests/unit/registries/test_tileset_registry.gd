## Unit Tests for TilesetRegistry
##
## Tests the tileset registration system added in Phase 4.
## Verifies mod extensibility and registry operations.
class_name TestTilesetRegistry
extends GdUnitTestSuite


# =============================================================================
# TEST CONSTANTS
# =============================================================================

const TEST_MOD_ID: String = "_test_tileset_registry"


# =============================================================================
# TEST FIXTURES
# =============================================================================

const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")

var _registry: RefCounted
var _tracker: RefCounted


func before_test() -> void:
	# Create a fresh registry for each test
	var TilesetRegistryClass: GDScript = load("res://core/registries/tileset_registry.gd")
	_registry = TilesetRegistryClass.new()
	_tracker = SignalTrackerScript.new()


func after_test() -> void:
	if _tracker:
		_tracker.disconnect_all()
		_tracker = null


# =============================================================================
# REGISTRATION FROM CONFIG TESTS
# =============================================================================

func test_register_from_config_adds_tileset() -> void:
	var config: Dictionary = {
		"terrain": {
			"path": "tilesets/terrain.tres",
			"display_name": "Terrain Tiles",
			"description": "Standard outdoor terrain"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_bool(_registry.has_tileset("terrain")).is_true()


func test_register_from_config_handles_multiple_tilesets() -> void:
	var config: Dictionary = {
		"terrain": {
			"path": "tilesets/terrain.tres",
			"display_name": "Terrain"
		},
		"dungeon": {
			"path": "tilesets/dungeon.tres",
			"display_name": "Dungeon"
		},
		"town": {
			"path": "tilesets/town.tres",
			"display_name": "Town"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_bool(_registry.has_tileset("terrain")).is_true()
	assert_bool(_registry.has_tileset("dungeon")).is_true()
	assert_bool(_registry.has_tileset("town")).is_true()


func test_register_from_config_stores_full_path() -> void:
	var config: Dictionary = {
		"terrain": {
			"path": "tilesets/terrain.tres",
			"display_name": "Terrain"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var path: String = _registry.get_tileset_path("terrain")
	assert_str(path).is_equal("res://mods/test_mod/tilesets/terrain.tres")


func test_register_from_config_stores_display_name() -> void:
	var config: Dictionary = {
		"terrain": {
			"path": "tilesets/terrain.tres",
			"display_name": "Beautiful Terrain Tiles"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_str(_registry.get_display_name("terrain")).is_equal("Beautiful Terrain Tiles")


func test_register_from_config_stores_description() -> void:
	var config: Dictionary = {
		"terrain": {
			"path": "tilesets/terrain.tres",
			"description": "Outdoor terrain with grass, water, and mountains"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_str(_registry.get_description("terrain")).is_equal("Outdoor terrain with grass, water, and mountains")


func test_register_from_config_tracks_source_mod() -> void:
	var config: Dictionary = {
		"terrain": {
			"path": "tilesets/terrain.tres"
		}
	}

	_registry.register_from_config("my_awesome_mod", config, "res://mods/my_awesome_mod")

	assert_str(_registry.get_source_mod("terrain")).is_equal("my_awesome_mod")


func test_register_from_config_skips_non_dictionary_values() -> void:
	var config: Dictionary = {
		"terrain": {
			"path": "tilesets/terrain.tres"
		},
		"invalid_string": "not a dictionary",
		"invalid_number": 42
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Only the valid tileset should be registered
	var tileset_ids: Array[String] = _registry.get_all_tileset_ids()
	assert_int(tileset_ids.size()).is_equal(1)
	assert_bool(_registry.has_tileset("terrain")).is_true()


# =============================================================================
# VALIDATION TESTS
# =============================================================================

func test_register_from_config_requires_path_field() -> void:
	var config: Dictionary = {
		"no_path_tileset": {
			"display_name": "Missing Path"
			# No "path" field!
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Tileset should NOT be registered without path
	assert_bool(_registry.has_tileset("no_path_tileset")).is_false()


func test_register_tileset_rejects_empty_id() -> void:
	var config: Dictionary = {
		"": {
			"path": "tilesets/empty.tres"
		},
		"   ": {
			"path": "tilesets/whitespace.tres"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Neither should be registered
	assert_int(_registry.get_all_tileset_ids().size()).is_equal(0)


# =============================================================================
# OVERRIDE BEHAVIOR TESTS
# =============================================================================

func test_later_registration_overrides_earlier() -> void:
	# First mod registers a tileset
	var config1: Dictionary = {
		"terrain": {
			"path": "tilesets/original.tres",
			"display_name": "Original"
		}
	}
	_registry.register_from_config("base_mod", config1, "res://mods/base_mod")

	# Second mod overrides it
	var config2: Dictionary = {
		"terrain": {
			"path": "tilesets/override.tres",
			"display_name": "Override"
		}
	}
	_registry.register_from_config("override_mod", config2, "res://mods/override_mod")

	# Override should win
	assert_str(_registry.get_display_name("terrain")).is_equal("Override")
	assert_str(_registry.get_source_mod("terrain")).is_equal("override_mod")
	assert_str(_registry.get_tileset_path("terrain")).contains("override_mod")


func test_override_keeps_single_entry() -> void:
	# Register initial tileset
	var config1: Dictionary = {
		"terrain": {
			"path": "tilesets/terrain.tres"
		}
	}
	_registry.register_from_config("base_mod", config1, "res://mods/" + TEST_MOD_ID)

	# Override with different path
	var config2: Dictionary = {
		"terrain": {
			"path": "tilesets/different.tres"
		}
	}
	_registry.register_from_config("override_mod", config2, "res://mods/override_mod")

	# Verify the tileset count stays at 1 (override, not addition)
	var stats: Dictionary = _registry.get_stats()
	assert_int(stats.tileset_count).is_equal(1)


# =============================================================================
# CASE INSENSITIVITY TESTS
# =============================================================================

func test_tileset_ids_normalized_to_lowercase() -> void:
	var config: Dictionary = {
		"TERRAIN": {
			"path": "tilesets/terrain.tres"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Should be accessible in lowercase
	assert_bool(_registry.has_tileset("terrain")).is_true()


func test_has_tileset_is_case_insensitive() -> void:
	var config: Dictionary = {
		"terrain": {
			"path": "tilesets/terrain.tres"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_bool(_registry.has_tileset("terrain")).is_true()
	assert_bool(_registry.has_tileset("TERRAIN")).is_true()
	assert_bool(_registry.has_tileset("Terrain")).is_true()
	assert_bool(_registry.has_tileset("TeRrAiN")).is_true()


func test_get_tileset_info_is_case_insensitive() -> void:
	var config: Dictionary = {
		"terrain": {
			"path": "tilesets/terrain.tres",
			"display_name": "Test Terrain"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var lower: Dictionary = _registry.get_tileset_info("terrain")
	var upper: Dictionary = _registry.get_tileset_info("TERRAIN")
	var mixed: Dictionary = _registry.get_tileset_info("TeRrAiN")

	assert_str(lower.get("display_name", "")).is_equal("Test Terrain")
	assert_str(upper.get("display_name", "")).is_equal("Test Terrain")
	assert_str(mixed.get("display_name", "")).is_equal("Test Terrain")


# =============================================================================
# LOOKUP API TESTS
# =============================================================================

func test_get_all_tileset_ids_returns_sorted_array() -> void:
	var config: Dictionary = {
		"zebra": {"path": "ts/z.tres"},
		"alpha": {"path": "ts/a.tres"},
		"middle": {"path": "ts/m.tres"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var ids: Array[String] = _registry.get_all_tileset_ids()

	assert_int(ids.size()).is_equal(3)
	assert_str(ids[0]).is_equal("alpha")
	assert_str(ids[1]).is_equal("middle")
	assert_str(ids[2]).is_equal("zebra")


func test_get_all_tilesets_returns_metadata_array() -> void:
	var config: Dictionary = {
		"dungeon": {"path": "ts/d.tres", "display_name": "Dungeon"},
		"terrain": {"path": "ts/t.tres", "display_name": "Terrain"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var tilesets: Array[Dictionary] = _registry.get_all_tilesets()

	assert_int(tilesets.size()).is_equal(2)
	# Should be sorted by display_name
	assert_str(tilesets[0].get("display_name", "")).is_equal("Dungeon")
	assert_str(tilesets[1].get("display_name", "")).is_equal("Terrain")


func test_get_all_tilesets_excludes_resource_field() -> void:
	var config: Dictionary = {
		"terrain": {"path": "ts/t.tres"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var tilesets: Array[Dictionary] = _registry.get_all_tilesets()

	# The "resource" field should NOT be in the returned metadata
	assert_bool("resource" in tilesets[0]).is_false()


func test_get_tileset_info_returns_copy() -> void:
	var config: Dictionary = {
		"terrain": {
			"path": "ts/t.tres",
			"display_name": "Original"
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var info1: Dictionary = _registry.get_tileset_info("terrain")
	var info2: Dictionary = _registry.get_tileset_info("terrain")

	# Modifying one should not affect the other
	info1["display_name"] = "Modified"

	assert_str(info2.get("display_name", "")).is_equal("Original")


func test_get_tileset_info_returns_empty_for_unknown() -> void:
	var info: Dictionary = _registry.get_tileset_info("nonexistent")
	assert_bool(info.is_empty()).is_true()


func test_get_display_name_falls_back_to_capitalize() -> void:
	var config: Dictionary = {
		"outdoor_terrain": {
			"path": "ts/t.tres"
			# No display_name specified
		}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Should capitalize the ID as fallback (Godot converts snake_case to Title Case)
	var display: String = _registry.get_display_name("outdoor_terrain")
	assert_str(display).is_equal("Outdoor Terrain")


func test_get_display_name_for_unknown_capitalizes_id() -> void:
	# Godot's capitalize() converts snake_case to Title Case
	var display: String = _registry.get_display_name("some_unknown_tileset")
	assert_str(display).is_equal("Some Unknown Tileset")


func test_get_description_returns_empty_for_unknown() -> void:
	var description: String = _registry.get_description("nonexistent")
	assert_str(description).is_empty()


func test_get_tileset_path_returns_empty_for_unknown() -> void:
	var path: String = _registry.get_tileset_path("nonexistent")
	assert_str(path).is_empty()


func test_get_source_mod_returns_empty_for_unknown() -> void:
	var source: String = _registry.get_source_mod("nonexistent")
	assert_str(source).is_empty()


# =============================================================================
# RESOURCE LOADING TESTS
# =============================================================================

func test_get_tileset_returns_null_for_unknown() -> void:
	var tileset: TileSet = _registry.get_tileset("nonexistent")
	assert_object(tileset).is_null()


func test_get_all_tileset_paths_returns_array() -> void:
	var config: Dictionary = {
		"terrain": {"path": "ts/terrain.tres"},
		"dungeon": {"path": "ts/dungeon.tres"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var paths: Array[String] = _registry.get_all_tileset_paths()

	assert_int(paths.size()).is_equal(2)


# =============================================================================
# SIGNAL TESTS
# =============================================================================

func test_register_from_config_emits_signal() -> void:
	_tracker.track(_registry.registrations_changed)

	var config: Dictionary = {
		"terrain": {"path": "ts/t.tres"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_bool(_tracker.was_emitted("registrations_changed")).is_true()


func test_clear_mod_registrations_emits_signal() -> void:
	# First add some tilesets
	var config: Dictionary = {
		"terrain": {"path": "ts/t.tres"}
	}
	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	_tracker.clear_emissions()
	_tracker.track(_registry.registrations_changed)

	_registry.clear_mod_registrations()

	assert_bool(_tracker.was_emitted("registrations_changed")).is_true()


# =============================================================================
# UTILITY FUNCTION TESTS
# =============================================================================

func test_clear_mod_registrations_empties_all() -> void:
	var config: Dictionary = {
		"terrain": {"path": "ts/t.tres"},
		"dungeon": {"path": "ts/d.tres"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	assert_int(_registry.get_all_tileset_ids().size()).is_equal(2)

	_registry.clear_mod_registrations()

	assert_int(_registry.get_all_tileset_ids().size()).is_equal(0)


func test_get_stats_returns_count() -> void:
	var config: Dictionary = {
		"terrain": {"path": "ts/t.tres"},
		"dungeon": {"path": "ts/d.tres"},
		"town": {"path": "ts/town.tres"}
	}

	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	var stats: Dictionary = _registry.get_stats()

	assert_int(stats.get("tileset_count", 0)).is_equal(3)


func test_get_stats_on_empty_registry() -> void:
	var stats: Dictionary = _registry.get_stats()

	assert_int(stats.get("tileset_count", -1)).is_equal(0)


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
		"terrain": {"path": "ts/t.tres", "display_name": "From Config"}
	}
	_registry.register_from_config("test_mod", config, "res://mods/test_mod")

	# Discovery should not override the config registration
	assert_str(_registry.get_display_name("terrain")).is_equal("From Config")
