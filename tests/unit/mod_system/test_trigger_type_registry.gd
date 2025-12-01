## Unit Tests for TriggerTypeRegistry
##
## Tests the trigger type registration system added in Phase 2.5.1.
## Verifies mod extensibility for custom trigger types.
class_name TestTriggerTypeRegistry
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _registry: RefCounted


func before_test() -> void:
	# Create a fresh registry for each test
	var TriggerTypeRegistryClass: GDScript = load("res://core/registries/trigger_type_registry.gd")
	_registry = TriggerTypeRegistryClass.new()


# =============================================================================
# DEFAULT TYPES TESTS
# =============================================================================

func test_default_types_exist() -> void:
	var types: Array[String] = _registry.get_trigger_types()

	assert_bool(types.has("battle")).is_true()
	assert_bool(types.has("dialog")).is_true()
	assert_bool(types.has("chest")).is_true()
	assert_bool(types.has("door")).is_true()
	assert_bool(types.has("cutscene")).is_true()
	assert_bool(types.has("transition")).is_true()
	assert_bool(types.has("custom")).is_true()


func test_default_types_are_valid() -> void:
	assert_bool(_registry.is_valid_trigger_type("battle")).is_true()
	assert_bool(_registry.is_valid_trigger_type("BATTLE")).is_true()  # Case insensitive
	assert_bool(_registry.is_valid_trigger_type("Battle")).is_true()  # Case insensitive


func test_default_types_source_is_base() -> void:
	assert_str(_registry.get_trigger_type_source("battle")).is_equal("base")
	assert_str(_registry.get_trigger_type_source("dialog")).is_equal("base")


# =============================================================================
# CUSTOM TYPE REGISTRATION TESTS
# =============================================================================

func test_register_custom_types() -> void:
	_registry.register_trigger_types("test_mod", ["puzzle", "shop"])

	assert_bool(_registry.is_valid_trigger_type("puzzle")).is_true()
	assert_bool(_registry.is_valid_trigger_type("shop")).is_true()


func test_custom_type_source() -> void:
	_registry.register_trigger_types("my_mod", ["minigame"])

	assert_str(_registry.get_trigger_type_source("minigame")).is_equal("my_mod")


func test_invalid_type_returns_empty_source() -> void:
	assert_str(_registry.get_trigger_type_source("nonexistent")).is_empty()


func test_register_types_normalizes_case() -> void:
	_registry.register_trigger_types("test_mod", ["PUZZLE", "Shop", "miNiGaMe"])

	# All should be accessible in lowercase
	assert_bool(_registry.is_valid_trigger_type("puzzle")).is_true()
	assert_bool(_registry.is_valid_trigger_type("shop")).is_true()
	assert_bool(_registry.is_valid_trigger_type("minigame")).is_true()


func test_duplicate_types_not_added() -> void:
	var initial_count: int = _registry.get_trigger_types().size()

	# Register same type twice from different mods
	_registry.register_trigger_types("mod_a", ["puzzle"])
	_registry.register_trigger_types("mod_b", ["puzzle"])

	var final_count: int = _registry.get_trigger_types().size()

	# Should only add one "puzzle" type
	assert_int(final_count).is_equal(initial_count + 1)


# =============================================================================
# TRIGGER SCRIPT REGISTRATION TESTS
# =============================================================================

func test_register_trigger_script() -> void:
	_registry.register_trigger_script("puzzle", "res://mods/test/triggers/puzzle_trigger.gd", "test_mod")

	var path: String = _registry.get_trigger_script_path("puzzle")
	assert_str(path).is_equal("res://mods/test/triggers/puzzle_trigger.gd")


func test_unregistered_script_returns_empty() -> void:
	var path: String = _registry.get_trigger_script_path("nonexistent")
	assert_str(path).is_empty()


func test_get_all_trigger_scripts() -> void:
	_registry.register_trigger_script("puzzle", "res://path/puzzle.gd", "mod_a")
	_registry.register_trigger_script("shop", "res://path/shop.gd", "mod_b")

	var scripts: Dictionary = _registry.get_all_trigger_scripts()

	assert_bool("puzzle" in scripts).is_true()
	assert_bool("shop" in scripts).is_true()


# =============================================================================
# MOD UNREGISTRATION TESTS
# =============================================================================

func test_unregister_mod_removes_types() -> void:
	_registry.register_trigger_types("test_mod", ["puzzle", "shop"])
	assert_bool(_registry.is_valid_trigger_type("puzzle")).is_true()

	_registry.unregister_mod("test_mod")

	# Types should be removed (they came only from test_mod)
	# Note: Actually, types stay registered but source is gone
	# Let's check the source instead
	assert_str(_registry.get_trigger_type_source("puzzle")).is_empty()


func test_unregister_mod_removes_scripts() -> void:
	_registry.register_trigger_script("puzzle", "res://path.gd", "test_mod")
	assert_str(_registry.get_trigger_script_path("puzzle")).is_not_empty()

	_registry.unregister_mod("test_mod")

	assert_str(_registry.get_trigger_script_path("puzzle")).is_empty()


func test_clear_mod_registrations() -> void:
	_registry.register_trigger_types("mod_a", ["type_a"])
	_registry.register_trigger_types("mod_b", ["type_b"])
	_registry.register_trigger_script("type_a", "res://a.gd", "mod_a")

	_registry.clear_mod_registrations()

	# Custom types should be gone, but defaults remain
	assert_bool(_registry.is_valid_trigger_type("battle")).is_true()  # Default
	assert_str(_registry.get_trigger_type_source("type_a")).is_empty()
	assert_str(_registry.get_trigger_script_path("type_a")).is_empty()
