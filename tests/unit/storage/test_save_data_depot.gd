## Unit Tests for SaveData depot_items serialization
##
## Tests depot storage persistence in save data.
class_name TestSaveDataDepot
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _save_data: SaveData


func before_test() -> void:
	_save_data = SaveData.new()


# =============================================================================
# DEPOT ITEMS FIELD
# =============================================================================

func test_depot_items_starts_empty() -> void:
	assert_array(_save_data.depot_items).is_empty()


func test_depot_items_can_be_added() -> void:
	_save_data.depot_items.append("healing_seed")
	_save_data.depot_items.append("bronze_sword")

	assert_int(_save_data.depot_items.size()).is_equal(2)


func test_depot_items_allows_duplicates() -> void:
	_save_data.depot_items.append("healing_seed")
	_save_data.depot_items.append("healing_seed")
	_save_data.depot_items.append("healing_seed")

	assert_int(_save_data.depot_items.size()).is_equal(3)


# =============================================================================
# SERIALIZATION
# =============================================================================

func test_serialize_includes_depot_items() -> void:
	_save_data.depot_items.append("healing_seed")
	_save_data.depot_items.append("bronze_sword")

	var serialized: Dictionary = _save_data.serialize_to_dict()

	assert_bool("depot_items" in serialized).is_true()
	assert_array(serialized.depot_items).has_size(2)


func test_serialize_depot_items_correct_values() -> void:
	_save_data.depot_items.append("item_a")
	_save_data.depot_items.append("item_b")

	var serialized: Dictionary = _save_data.serialize_to_dict()

	assert_str(serialized.depot_items[0]).is_equal("item_a")
	assert_str(serialized.depot_items[1]).is_equal("item_b")


# =============================================================================
# DESERIALIZATION
# =============================================================================

func test_deserialize_depot_items() -> void:
	var data: Dictionary = {
		"depot_items": ["healing_seed", "bronze_sword", "power_ring"]
	}

	_save_data.deserialize_from_dict(data)

	assert_int(_save_data.depot_items.size()).is_equal(3)
	assert_str(_save_data.depot_items[0]).is_equal("healing_seed")
	assert_str(_save_data.depot_items[1]).is_equal("bronze_sword")
	assert_str(_save_data.depot_items[2]).is_equal("power_ring")


func test_deserialize_without_depot_items_keeps_empty() -> void:
	# Simulates loading a v1 save (pre-depot)
	var data: Dictionary = {
		"save_version": 1,
		"gold": 100
	}

	_save_data.deserialize_from_dict(data)

	assert_array(_save_data.depot_items).is_empty()


func test_deserialize_clears_existing_depot_items() -> void:
	_save_data.depot_items.append("old_item")

	var data: Dictionary = {
		"depot_items": ["new_item"]
	}

	_save_data.deserialize_from_dict(data)

	assert_int(_save_data.depot_items.size()).is_equal(1)
	assert_str(_save_data.depot_items[0]).is_equal("new_item")


func test_deserialize_filters_non_string_values() -> void:
	var data: Dictionary = {
		"depot_items": ["valid_item", 123, "another_valid", null]
	}

	_save_data.deserialize_from_dict(data)

	# Only strings should be added
	assert_int(_save_data.depot_items.size()).is_equal(2)


# =============================================================================
# ROUND-TRIP SERIALIZATION
# =============================================================================

func test_roundtrip_preserves_depot_items() -> void:
	_save_data.depot_items.append("healing_seed")
	_save_data.depot_items.append("bronze_sword")
	_save_data.depot_items.append("healing_seed")  # Duplicate

	var serialized: Dictionary = _save_data.serialize_to_dict()

	var loaded: SaveData = SaveData.new()
	loaded.deserialize_from_dict(serialized)

	assert_int(loaded.depot_items.size()).is_equal(3)
	assert_str(loaded.depot_items[0]).is_equal("healing_seed")
	assert_str(loaded.depot_items[1]).is_equal("bronze_sword")
	assert_str(loaded.depot_items[2]).is_equal("healing_seed")


# =============================================================================
# VERSION COMPATIBILITY
# =============================================================================

func test_save_version_is_2() -> void:
	assert_int(_save_data.save_version).is_equal(2)


func test_v1_save_loads_without_depot() -> void:
	# Simulate a version 1 save file (no depot_items field)
	var v1_data: Dictionary = {
		"save_version": 1,
		"slot_number": 1,
		"game_version": "0.1.0",
		"gold": 500,
		"party_members": []
	}

	_save_data.deserialize_from_dict(v1_data)

	# Should load successfully with empty depot
	assert_array(_save_data.depot_items).is_empty()
	assert_int(_save_data.gold).is_equal(500)
