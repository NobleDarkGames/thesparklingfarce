## Unit Tests for InventoryConfig
##
## Tests configurable inventory system defaults and mod loading.
class_name TestInventoryConfig
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _config: InventoryConfig


func before_test() -> void:
	_config = InventoryConfig.new()


# =============================================================================
# DEFAULT VALUES TESTS
# =============================================================================

func test_default_slots_per_character() -> void:
	assert_int(_config.get_max_slots()).is_equal(4)


func test_default_allow_duplicates() -> void:
	assert_bool(_config.allows_duplicates()).is_true()


func test_default_source_mod_is_base() -> void:
	assert_str(_config.get_source_mod()).is_equal("base")


# =============================================================================
# MANIFEST LOADING TESTS
# =============================================================================

func test_load_custom_slots_per_character() -> void:
	var manifest_config: Dictionary = {
		"slots_per_character": 6
	}

	_config.load_from_manifest("test_mod", manifest_config)

	assert_int(_config.get_max_slots()).is_equal(6)


func test_load_disallow_duplicates() -> void:
	var manifest_config: Dictionary = {
		"allow_duplicates": false
	}

	_config.load_from_manifest("test_mod", manifest_config)

	assert_bool(_config.allows_duplicates()).is_false()


func test_load_sets_source_mod() -> void:
	var manifest_config: Dictionary = {
		"slots_per_character": 8
	}

	_config.load_from_manifest("my_custom_mod", manifest_config)

	assert_str(_config.get_source_mod()).is_equal("my_custom_mod")


func test_load_clamps_slots_to_minimum_1() -> void:
	var manifest_config: Dictionary = {
		"slots_per_character": 0
	}

	_config.load_from_manifest("test_mod", manifest_config)

	assert_int(_config.get_max_slots()).is_equal(1)


func test_load_ignores_invalid_types() -> void:
	var manifest_config: Dictionary = {
		"slots_per_character": "invalid",
		"allow_duplicates": "also_invalid"
	}

	_config.load_from_manifest("test_mod", manifest_config)

	# Should retain defaults
	assert_int(_config.get_max_slots()).is_equal(4)
	assert_bool(_config.allows_duplicates()).is_true()


# =============================================================================
# RESET TESTS
# =============================================================================

func test_reset_to_defaults() -> void:
	_config.load_from_manifest("test_mod", {"slots_per_character": 10, "allow_duplicates": false})

	_config.reset_to_defaults()

	assert_int(_config.get_max_slots()).is_equal(4)
	assert_bool(_config.allows_duplicates()).is_true()
	assert_str(_config.get_source_mod()).is_equal("base")
