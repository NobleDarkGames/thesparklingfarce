## Unit Tests for CharacterSaveData Equipment and Inventory
##
## Tests equipped_items with curse_broken and inventory array serialization.
class_name TestCharacterSaveEquipment
extends GdUnitTestSuite


# =============================================================================
# TEST CONSTANTS
# =============================================================================

const TEST_MOD_ID: String = "_test_equipment_save"


# =============================================================================
# TEST FIXTURES
# =============================================================================

func _create_base_save_data() -> CharacterSaveData:
	var save_data: CharacterSaveData = CharacterSaveData.new()
	save_data.character_mod_id = TEST_MOD_ID
	save_data.character_resource_id = "max"
	save_data.fallback_character_name = "Max"
	save_data.fallback_class_name = "Warrior"
	save_data.level = 5
	save_data.current_hp = 30
	save_data.max_hp = 30
	return save_data


# =============================================================================
# EQUIPPED ITEMS FORMAT TESTS
# =============================================================================

func test_equipped_items_empty_by_default() -> void:
	var save_data: CharacterSaveData = _create_base_save_data()
	assert_int(save_data.equipped_items.size()).is_equal(0)


func test_equipped_items_with_curse_broken_field() -> void:
	var save_data: CharacterSaveData = _create_base_save_data()
	save_data.equipped_items.append({
		"slot": "weapon",
		"mod_id": TEST_MOD_ID,
		"item_id": "bronze_sword",
		"curse_broken": false
	})

	assert_int(save_data.equipped_items.size()).is_equal(1)
	assert_bool(save_data.equipped_items[0]["curse_broken"]).is_false()


func test_equipped_items_curse_broken_true() -> void:
	var save_data: CharacterSaveData = _create_base_save_data()
	save_data.equipped_items.append({
		"slot": "weapon",
		"mod_id": TEST_MOD_ID,
		"item_id": "cursed_blade",
		"curse_broken": true
	})

	assert_bool(save_data.equipped_items[0]["curse_broken"]).is_true()


# =============================================================================
# INVENTORY TESTS
# =============================================================================

func test_inventory_empty_by_default() -> void:
	var save_data: CharacterSaveData = _create_base_save_data()
	assert_int(save_data.inventory.size()).is_equal(0)


func test_inventory_with_items() -> void:
	var save_data: CharacterSaveData = _create_base_save_data()
	save_data.inventory.append("healing_herb")
	save_data.inventory.append("antidote")
	save_data.inventory.append("healing_herb")

	assert_int(save_data.inventory.size()).is_equal(3)
	assert_str(save_data.inventory[0]).is_equal("healing_herb")
	assert_str(save_data.inventory[2]).is_equal("healing_herb")


# =============================================================================
# SERIALIZATION TESTS
# =============================================================================

func test_serialize_includes_equipped_items() -> void:
	var save_data: CharacterSaveData = _create_base_save_data()
	save_data.equipped_items.append({
		"slot": "weapon",
		"mod_id": TEST_MOD_ID,
		"item_id": "bronze_sword",
		"curse_broken": false
	})

	var serialized: Dictionary = save_data.serialize_to_dict()

	assert_bool("equipped_items" in serialized).is_true()
	assert_int(serialized.equipped_items.size()).is_equal(1)
	assert_str(serialized.equipped_items[0]["slot"]).is_equal("weapon")
	assert_bool(serialized.equipped_items[0]["curse_broken"]).is_false()


func test_serialize_includes_inventory() -> void:
	var save_data: CharacterSaveData = _create_base_save_data()
	save_data.inventory.append("healing_herb")
	save_data.inventory.append("antidote")

	var serialized: Dictionary = save_data.serialize_to_dict()

	assert_bool("inventory" in serialized).is_true()
	assert_int(serialized.inventory.size()).is_equal(2)
	assert_str(serialized.inventory[0]).is_equal("healing_herb")


# =============================================================================
# DESERIALIZATION TESTS
# =============================================================================

func test_deserialize_equipped_items_with_curse_broken() -> void:
	var data: Dictionary = {
		"character_mod_id": TEST_MOD_ID,
		"character_resource_id": "max",
		"fallback_character_name": "Max",
		"fallback_class_name": "Warrior",
		"level": 5,
		"current_xp": 0,
		"current_hp": 30,
		"max_hp": 30,
		"current_mp": 10,
		"max_mp": 10,
		"strength": 12,
		"defense": 10,
		"agility": 8,
		"intelligence": 5,
		"luck": 5,
		"equipped_items": [
			{"slot": "weapon", "mod_id": TEST_MOD_ID, "item_id": "cursed_blade", "curse_broken": true}
		],
		"inventory": [],
		"learned_abilities": [],
		"is_alive": true,
		"is_available": true,
		"is_hero": true,
		"recruitment_chapter": ""
	}

	var save_data: CharacterSaveData = CharacterSaveData.new()
	save_data.deserialize_from_dict(data)

	assert_int(save_data.equipped_items.size()).is_equal(1)
	assert_bool(save_data.equipped_items[0]["curse_broken"]).is_true()


func test_deserialize_equipped_items_adds_curse_broken_if_missing() -> void:
	var data: Dictionary = {
		"character_mod_id": TEST_MOD_ID,
		"character_resource_id": "max",
		"fallback_character_name": "Max",
		"fallback_class_name": "Warrior",
		"level": 5,
		"current_xp": 0,
		"current_hp": 30,
		"max_hp": 30,
		"current_mp": 10,
		"max_mp": 10,
		"strength": 12,
		"defense": 10,
		"agility": 8,
		"intelligence": 5,
		"luck": 5,
		"equipped_items": [
			{"slot": "weapon", "mod_id": TEST_MOD_ID, "item_id": "bronze_sword"}
		],
		"inventory": [],
		"learned_abilities": [],
		"is_alive": true,
		"is_available": true,
		"is_hero": true,
		"recruitment_chapter": ""
	}

	var save_data: CharacterSaveData = CharacterSaveData.new()
	save_data.deserialize_from_dict(data)

	# Should have added curse_broken = false for backward compatibility
	assert_bool("curse_broken" in save_data.equipped_items[0]).is_true()
	assert_bool(save_data.equipped_items[0]["curse_broken"]).is_false()


func test_deserialize_inventory() -> void:
	var data: Dictionary = {
		"character_mod_id": TEST_MOD_ID,
		"character_resource_id": "max",
		"fallback_character_name": "Max",
		"fallback_class_name": "Warrior",
		"level": 5,
		"current_xp": 0,
		"current_hp": 30,
		"max_hp": 30,
		"current_mp": 10,
		"max_mp": 10,
		"strength": 12,
		"defense": 10,
		"agility": 8,
		"intelligence": 5,
		"luck": 5,
		"equipped_items": [],
		"inventory": ["healing_herb", "antidote", "power_ring"],
		"learned_abilities": [],
		"is_alive": true,
		"is_available": true,
		"is_hero": true,
		"recruitment_chapter": ""
	}

	var save_data: CharacterSaveData = CharacterSaveData.new()
	save_data.deserialize_from_dict(data)

	assert_int(save_data.inventory.size()).is_equal(3)
	assert_str(save_data.inventory[0]).is_equal("healing_herb")
	assert_str(save_data.inventory[1]).is_equal("antidote")
	assert_str(save_data.inventory[2]).is_equal("power_ring")


func test_deserialize_missing_inventory_keeps_empty() -> void:
	var data: Dictionary = {
		"character_mod_id": TEST_MOD_ID,
		"character_resource_id": "max",
		"fallback_character_name": "Max",
		"fallback_class_name": "Warrior",
		"level": 5,
		"current_xp": 0,
		"current_hp": 30,
		"max_hp": 30,
		"current_mp": 10,
		"max_mp": 10,
		"strength": 12,
		"defense": 10,
		"agility": 8,
		"intelligence": 5,
		"luck": 5,
		"equipped_items": [],
		"learned_abilities": [],
		"is_alive": true,
		"is_available": true,
		"is_hero": true,
		"recruitment_chapter": ""
		# Note: inventory field missing (old save format)
	}

	var save_data: CharacterSaveData = CharacterSaveData.new()
	save_data.deserialize_from_dict(data)

	# Should retain empty inventory (default)
	assert_int(save_data.inventory.size()).is_equal(0)
