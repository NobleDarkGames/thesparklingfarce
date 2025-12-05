## Unit Tests for StorageManager (Caravan Depot)
##
## Tests shared storage depot operations and signals.
class_name TestStorageManager
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

## We test StorageManager's internal state directly by creating a fresh instance
## rather than using the autoload to avoid cross-test contamination.
var _storage: Node


func before_test() -> void:
	# Create a fresh StorageManager instance for each test
	_storage = load("res://core/systems/storage_manager.gd").new()
	_storage._ready()


func after_test() -> void:
	if _storage:
		_storage.free()


# =============================================================================
# BASIC DEPOT OPERATIONS
# =============================================================================

func test_depot_starts_empty() -> void:
	assert_bool(_storage.is_empty()).is_true()
	assert_int(_storage.get_depot_size()).is_equal(0)


func test_add_item_to_depot() -> void:
	var result: bool = _storage.add_to_depot("healing_seed")

	assert_bool(result).is_true()
	assert_int(_storage.get_depot_size()).is_equal(1)
	assert_bool(_storage.has_item("healing_seed")).is_true()


func test_add_multiple_items() -> void:
	_storage.add_to_depot("healing_seed")
	_storage.add_to_depot("bronze_sword")
	_storage.add_to_depot("healing_seed")  # Duplicate

	assert_int(_storage.get_depot_size()).is_equal(3)
	assert_int(_storage.get_unique_item_count()).is_equal(2)


func test_remove_item_from_depot() -> void:
	_storage.add_to_depot("healing_seed")
	_storage.add_to_depot("healing_seed")

	var result: bool = _storage.remove_from_depot("healing_seed")

	assert_bool(result).is_true()
	assert_int(_storage.get_depot_size()).is_equal(1)
	assert_bool(_storage.has_item("healing_seed")).is_true()  # One still remains


func test_remove_nonexistent_item_returns_false() -> void:
	var result: bool = _storage.remove_from_depot("nonexistent_item")

	assert_bool(result).is_false()


func test_remove_all_of_item() -> void:
	_storage.add_to_depot("healing_seed")
	_storage.add_to_depot("healing_seed")
	_storage.add_to_depot("healing_seed")
	_storage.add_to_depot("bronze_sword")

	var removed: int = _storage.remove_all_from_depot("healing_seed")

	assert_int(removed).is_equal(3)
	assert_bool(_storage.has_item("healing_seed")).is_false()
	assert_bool(_storage.has_item("bronze_sword")).is_true()


func test_clear_depot() -> void:
	_storage.add_to_depot("healing_seed")
	_storage.add_to_depot("bronze_sword")

	_storage.clear_depot()

	assert_bool(_storage.is_empty()).is_true()


# =============================================================================
# ITEM COUNT QUERIES
# =============================================================================

func test_get_item_count() -> void:
	_storage.add_to_depot("healing_seed")
	_storage.add_to_depot("healing_seed")
	_storage.add_to_depot("healing_seed")
	_storage.add_to_depot("bronze_sword")

	assert_int(_storage.get_item_count("healing_seed")).is_equal(3)
	assert_int(_storage.get_item_count("bronze_sword")).is_equal(1)
	assert_int(_storage.get_item_count("nonexistent")).is_equal(0)


func test_get_depot_contents_stacked() -> void:
	_storage.add_to_depot("healing_seed")
	_storage.add_to_depot("healing_seed")
	_storage.add_to_depot("bronze_sword")

	var stacked: Array[Dictionary] = _storage.get_depot_contents_stacked()

	# Should have 2 unique items
	assert_int(stacked.size()).is_equal(2)

	# Find healing_seed entry
	var healing_entry: Dictionary = {}
	for entry: Dictionary in stacked:
		if entry.item_id == "healing_seed":
			healing_entry = entry
			break

	assert_int(healing_entry.quantity).is_equal(2)


# =============================================================================
# CAPACITY TESTS
# =============================================================================

func test_unlimited_capacity_by_default() -> void:
	assert_int(_storage.capacity_limit).is_equal(-1)
	assert_bool(_storage.is_full()).is_false()
	assert_int(_storage.get_remaining_capacity()).is_equal(-1)


func test_capacity_limit_enforced() -> void:
	_storage.capacity_limit = 3

	_storage.add_to_depot("item_1")
	_storage.add_to_depot("item_2")
	_storage.add_to_depot("item_3")
	var result: bool = _storage.add_to_depot("item_4")  # Should fail

	assert_bool(result).is_false()
	assert_int(_storage.get_depot_size()).is_equal(3)
	assert_bool(_storage.is_full()).is_true()


func test_remaining_capacity() -> void:
	_storage.capacity_limit = 5
	_storage.add_to_depot("item_1")
	_storage.add_to_depot("item_2")

	assert_int(_storage.get_remaining_capacity()).is_equal(3)


# =============================================================================
# BATCH OPERATIONS
# =============================================================================

func test_add_multiple_to_depot() -> void:
	var items: Array[String] = ["healing_seed", "bronze_sword", "power_ring"]

	var added: int = _storage.add_multiple_to_depot(items)

	assert_int(added).is_equal(3)
	assert_int(_storage.get_depot_size()).is_equal(3)


func test_remove_multiple_from_depot() -> void:
	_storage.add_to_depot("healing_seed")
	_storage.add_to_depot("bronze_sword")
	_storage.add_to_depot("power_ring")

	var items_to_remove: Array[String] = ["healing_seed", "bronze_sword"]
	var removed: int = _storage.remove_multiple_from_depot(items_to_remove)

	assert_int(removed).is_equal(2)
	assert_int(_storage.get_depot_size()).is_equal(1)
	assert_bool(_storage.has_item("power_ring")).is_true()


# =============================================================================
# SAVE/LOAD STATE
# =============================================================================

func test_export_state() -> void:
	_storage.add_to_depot("healing_seed")
	_storage.add_to_depot("bronze_sword")

	var exported: Array[String] = _storage.export_state()

	assert_int(exported.size()).is_equal(2)
	assert_bool("healing_seed" in exported).is_true()
	assert_bool("bronze_sword" in exported).is_true()


func test_import_state() -> void:
	var items: Array = ["healing_seed", "bronze_sword", "power_ring"]

	_storage.import_state(items)

	assert_int(_storage.get_depot_size()).is_equal(3)
	assert_bool(_storage.has_item("healing_seed")).is_true()
	assert_bool(_storage.has_item("bronze_sword")).is_true()
	assert_bool(_storage.has_item("power_ring")).is_true()


func test_import_state_clears_existing() -> void:
	_storage.add_to_depot("old_item")

	var items: Array = ["new_item"]
	_storage.import_state(items)

	assert_int(_storage.get_depot_size()).is_equal(1)
	assert_bool(_storage.has_item("old_item")).is_false()
	assert_bool(_storage.has_item("new_item")).is_true()


func test_import_state_filters_invalid_entries() -> void:
	var items: Array = ["valid_item", "", 123, "another_valid"]

	_storage.import_state(items)

	assert_int(_storage.get_depot_size()).is_equal(2)


func test_reset() -> void:
	_storage.capacity_limit = 10
	_storage.add_to_depot("item_1")
	_storage.add_to_depot("item_2")

	_storage.reset()

	assert_bool(_storage.is_empty()).is_true()
	assert_int(_storage.capacity_limit).is_equal(-1)


# =============================================================================
# INPUT VALIDATION
# =============================================================================

func test_add_empty_item_id_returns_false() -> void:
	var result: bool = _storage.add_to_depot("")

	assert_bool(result).is_false()
	assert_int(_storage.get_depot_size()).is_equal(0)


func test_remove_empty_item_id_returns_false() -> void:
	var result: bool = _storage.remove_from_depot("")

	assert_bool(result).is_false()


# =============================================================================
# MOD CONFIG
# =============================================================================

func test_load_config_sets_capacity() -> void:
	var config: Dictionary = {"capacity": 50}

	_storage.load_config_from_manifest("test_mod", config)

	assert_int(_storage.capacity_limit).is_equal(50)


func test_load_config_negative_capacity_unlimited() -> void:
	var config: Dictionary = {"capacity": -1}

	_storage.load_config_from_manifest("test_mod", config)

	assert_int(_storage.capacity_limit).is_equal(-1)
