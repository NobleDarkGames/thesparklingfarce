## EquipmentManager Integration Test
##
## Tests the EquipmentManager autoload functionality:
## - Equip/unequip operations
## - Validation (class restrictions, slot compatibility)
## - Curse mechanics
## - Query functions (stat bonuses, equipped items)
class_name TestEquipmentManager
extends GdUnitTestSuite


const TEST_MOD_ID: String = "_test_equipment_manager"

# Test data
var _save_data: CharacterSaveData
var _test_items: Array[ItemData] = []
var _test_classes: Array[ClassData] = []


func before() -> void:
	_save_data = null
	_test_items.clear()
	_test_classes.clear()


func after() -> void:
	# Clean up registered test resources
	ModLoader.registry.clear_mod_resources(TEST_MOD_ID)
	_test_items.clear()
	_test_classes.clear()


func before_test() -> void:
	# Create fresh save data for each test
	_save_data = CharacterSaveData.new()
	_save_data.character_resource_id = "test_hero"
	_save_data.equipped_items = []


# =============================================================================
# TEST: Basic Equip/Unequip
# =============================================================================

func test_equip_item_to_empty_slot() -> void:
	var sword: ItemData = _create_and_register_weapon("test_sword", "sword")

	var result: Dictionary = EquipmentManager.equip_item(_save_data, "weapon", "test_sword")

	assert_bool(result.success).is_true()
	assert_str(result.error).is_empty()
	assert_str(EquipmentManager.get_equipped_item_id(_save_data, "weapon")).is_equal("test_sword")


func test_equip_item_replacing_existing() -> void:
	var sword: ItemData = _create_and_register_weapon("sword_1", "sword")
	var axe: ItemData = _create_and_register_weapon("axe_1", "axe")

	# Equip first weapon
	EquipmentManager.equip_item(_save_data, "weapon", "sword_1")
	assert_str(EquipmentManager.get_equipped_item_id(_save_data, "weapon")).is_equal("sword_1")

	# Replace with second weapon
	var result: Dictionary = EquipmentManager.equip_item(_save_data, "weapon", "axe_1")

	assert_bool(result.success).is_true()
	assert_str(result.unequipped_item_id).is_equal("sword_1")
	assert_str(EquipmentManager.get_equipped_item_id(_save_data, "weapon")).is_equal("axe_1")


func test_unequip_item() -> void:
	var sword: ItemData = _create_and_register_weapon("unequip_sword", "sword")
	EquipmentManager.equip_item(_save_data, "weapon", "unequip_sword")

	var result: Dictionary = EquipmentManager.unequip_item(_save_data, "weapon")

	assert_bool(result.success).is_true()
	assert_str(result.unequipped_item_id).is_equal("unequip_sword")
	assert_str(EquipmentManager.get_equipped_item_id(_save_data, "weapon")).is_empty()


func test_unequip_empty_slot_succeeds() -> void:
	var result: Dictionary = EquipmentManager.unequip_item(_save_data, "weapon")

	assert_bool(result.success).is_true()
	assert_str(result.unequipped_item_id).is_empty()


# =============================================================================
# TEST: Validation
# =============================================================================

func test_cannot_equip_nonexistent_item() -> void:
	var result: Dictionary = EquipmentManager.can_equip(_save_data, "weapon", "nonexistent_item")

	assert_bool(result.can_equip).is_false()
	assert_str(result.reason).is_equal("Item not found")


func test_cannot_equip_consumable_item() -> void:
	var potion: ItemData = _create_and_register_consumable("health_potion")

	var result: Dictionary = EquipmentManager.can_equip(_save_data, "weapon", "health_potion")

	assert_bool(result.can_equip).is_false()
	assert_str(result.reason).is_equal("Item cannot be equipped")


func test_cannot_equip_to_invalid_slot() -> void:
	var sword: ItemData = _create_and_register_weapon("slot_test_sword", "sword")

	var result: Dictionary = EquipmentManager.can_equip(_save_data, "invalid_slot_xyz", "slot_test_sword")

	assert_bool(result.can_equip).is_false()
	assert_str(result.reason).is_equal("Invalid equipment slot")


func test_equip_with_invalid_save_data_fails() -> void:
	var result: Dictionary = EquipmentManager.equip_item(null, "weapon", "test_item")

	assert_bool(result.success).is_false()
	assert_str(result.error).is_equal("Invalid save data")


# =============================================================================
# TEST: Curse Mechanics
# =============================================================================

func test_cannot_unequip_cursed_item() -> void:
	var cursed_sword: ItemData = _create_and_register_weapon("cursed_blade", "sword", true)
	EquipmentManager.equip_item(_save_data, "weapon", "cursed_blade")

	var result: Dictionary = EquipmentManager.unequip_item(_save_data, "weapon")

	assert_bool(result.success).is_false()
	assert_str(result.error).is_equal("Cannot unequip cursed item")


func test_cannot_replace_cursed_item() -> void:
	var cursed_sword: ItemData = _create_and_register_weapon("curse_sword", "sword", true)
	var normal_sword: ItemData = _create_and_register_weapon("normal_sword", "sword", false)

	EquipmentManager.equip_item(_save_data, "weapon", "curse_sword")
	var result: Dictionary = EquipmentManager.equip_item(_save_data, "weapon", "normal_sword")

	assert_bool(result.success).is_false()
	assert_str(result.error).is_equal("Slot contains cursed item")


func test_is_slot_cursed_returns_true_for_cursed_item() -> void:
	var cursed_item: ItemData = _create_and_register_weapon("cursed_test", "sword", true)
	EquipmentManager.equip_item(_save_data, "weapon", "cursed_test")

	assert_bool(EquipmentManager.is_slot_cursed(_save_data, "weapon")).is_true()


func test_is_slot_cursed_returns_false_for_empty_slot() -> void:
	assert_bool(EquipmentManager.is_slot_cursed(_save_data, "weapon")).is_false()


func test_is_slot_cursed_returns_false_for_normal_item() -> void:
	var normal_item: ItemData = _create_and_register_weapon("normal_test", "sword", false)
	EquipmentManager.equip_item(_save_data, "weapon", "normal_test")

	assert_bool(EquipmentManager.is_slot_cursed(_save_data, "weapon")).is_false()


func test_uncurse_with_church_method() -> void:
	var cursed_item: ItemData = _create_and_register_weapon("church_curse", "sword", true)
	EquipmentManager.equip_item(_save_data, "weapon", "church_curse")

	var result: Dictionary = EquipmentManager.attempt_uncurse(_save_data, "weapon", "church")

	assert_bool(result.success).is_true()
	assert_bool(EquipmentManager.is_slot_cursed(_save_data, "weapon")).is_false()


func test_can_unequip_after_curse_broken() -> void:
	var cursed_item: ItemData = _create_and_register_weapon("breakable_curse", "sword", true)
	EquipmentManager.equip_item(_save_data, "weapon", "breakable_curse")

	# Break the curse
	EquipmentManager.attempt_uncurse(_save_data, "weapon", "church")

	# Now we should be able to unequip
	var result: Dictionary = EquipmentManager.unequip_item(_save_data, "weapon")
	assert_bool(result.success).is_true()


# =============================================================================
# TEST: Query Functions
# =============================================================================

func test_get_equipped_items_returns_all_items() -> void:
	var sword: ItemData = _create_and_register_weapon("query_sword", "sword")
	var ring: ItemData = _create_and_register_accessory("query_ring")

	EquipmentManager.equip_item(_save_data, "weapon", "query_sword")
	EquipmentManager.equip_item(_save_data, "ring_1", "query_ring")

	var equipped: Dictionary = EquipmentManager.get_equipped_items(_save_data)

	assert_int(equipped.size()).is_equal(2)
	assert_bool("weapon" in equipped).is_true()
	assert_bool("ring_1" in equipped).is_true()


func test_get_total_equipment_bonus_sums_modifiers() -> void:
	var sword: ItemData = _create_and_register_weapon("bonus_sword", "sword")
	sword.strength_modifier = 5

	var ring: ItemData = _create_and_register_accessory("bonus_ring")
	ring.strength_modifier = 3

	EquipmentManager.equip_item(_save_data, "weapon", "bonus_sword")
	EquipmentManager.equip_item(_save_data, "ring_1", "bonus_ring")

	var bonus: int = EquipmentManager.get_total_equipment_bonus(_save_data, "strength")

	assert_int(bonus).is_equal(8)


func test_get_equipped_weapon_returns_weapon_data() -> void:
	var sword: ItemData = _create_and_register_weapon("weapon_query_sword", "sword")

	EquipmentManager.equip_item(_save_data, "weapon", "weapon_query_sword")

	var weapon: ItemData = EquipmentManager.get_equipped_weapon(_save_data)

	assert_object(weapon).is_not_null()
	assert_str(weapon.item_name).is_equal("Weapon Query Sword")


func test_get_equipped_weapon_returns_null_when_no_weapon() -> void:
	var weapon: ItemData = EquipmentManager.get_equipped_weapon(_save_data)

	assert_object(weapon).is_null()


# =============================================================================
# TEST FIXTURES
# =============================================================================

func _create_and_register_weapon(item_id: String, weapon_type: String, is_cursed: bool = false) -> ItemData:
	var item: ItemData = ItemData.new()
	item.item_name = item_id.capitalize()
	item.item_type = ItemData.ItemType.WEAPON
	item.equipment_type = weapon_type
	item.equipment_slot = "weapon"
	item.is_cursed = is_cursed
	item.attack_power = 10
	item.hit_rate = 90
	item.critical_rate = 5

	ModLoader.registry.register_resource(item, "item", item_id, TEST_MOD_ID)
	_test_items.append(item)
	return item


func _create_and_register_accessory(item_id: String) -> ItemData:
	var item: ItemData = ItemData.new()
	item.item_name = item_id.capitalize()
	item.item_type = ItemData.ItemType.ACCESSORY
	item.equipment_type = "ring"
	item.equipment_slot = "ring_1"

	ModLoader.registry.register_resource(item, "item", item_id, TEST_MOD_ID)
	_test_items.append(item)
	return item


func _create_and_register_consumable(item_id: String) -> ItemData:
	var item: ItemData = ItemData.new()
	item.item_name = item_id.capitalize()
	item.item_type = ItemData.ItemType.CONSUMABLE
	item.equipment_type = ""
	item.equipment_slot = ""

	ModLoader.registry.register_resource(item, "item", item_id, TEST_MOD_ID)
	_test_items.append(item)
	return item
