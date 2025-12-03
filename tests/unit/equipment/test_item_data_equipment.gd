## Unit Tests for ItemData Equipment Properties
##
## Tests equipment slot, curse mechanics, and validation.
class_name TestItemDataEquipment
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

func _create_weapon(
	name: String = "Test Sword",
	equipment_type: String = "sword",
	equipment_slot: String = "weapon"
) -> ItemData:
	var item: ItemData = ItemData.new()
	item.item_name = name
	item.item_type = ItemData.ItemType.WEAPON
	item.equipment_type = equipment_type
	item.equipment_slot = equipment_slot
	item.attack_power = 10
	item.attack_range = 1
	item.hit_rate = 90
	item.critical_rate = 5
	return item


func _create_ring(
	name: String = "Test Ring",
	slot: String = "ring_1"
) -> ItemData:
	var item: ItemData = ItemData.new()
	item.item_name = name
	item.item_type = ItemData.ItemType.ACCESSORY
	item.equipment_type = "ring"
	item.equipment_slot = slot
	item.hp_modifier = 5
	return item


func _create_cursed_item(
	name: String = "Cursed Blade",
	uncurse_items: Array[String] = []
) -> ItemData:
	var item: ItemData = _create_weapon(name)
	item.is_cursed = true
	item.uncurse_items = uncurse_items
	return item


# =============================================================================
# EQUIPMENT SLOT PROPERTY TESTS
# =============================================================================

func test_weapon_default_slot() -> void:
	var item: ItemData = _create_weapon()
	assert_str(item.equipment_slot).is_equal("weapon")


func test_ring_slot_ring_1() -> void:
	var item: ItemData = _create_ring("Ring 1", "ring_1")
	assert_str(item.equipment_slot).is_equal("ring_1")


func test_ring_slot_ring_2() -> void:
	var item: ItemData = _create_ring("Ring 2", "ring_2")
	assert_str(item.equipment_slot).is_equal("ring_2")


# =============================================================================
# CURSE PROPERTY TESTS
# =============================================================================

func test_item_not_cursed_by_default() -> void:
	var item: ItemData = _create_weapon()
	assert_bool(item.is_cursed).is_false()


func test_cursed_item_is_cursed() -> void:
	var item: ItemData = _create_cursed_item()
	assert_bool(item.is_cursed).is_true()


func test_uncurse_items_empty_by_default() -> void:
	var item: ItemData = _create_weapon()
	assert_int(item.uncurse_items.size()).is_equal(0)


func test_cursed_item_with_uncurse_items() -> void:
	var uncurse: Array[String] = ["purify_scroll", "holy_water"]
	var item: ItemData = _create_cursed_item("Evil Sword", uncurse)
	assert_int(item.uncurse_items.size()).is_equal(2)
	assert_bool("purify_scroll" in item.uncurse_items).is_true()


# =============================================================================
# CURSE HELPER METHOD TESTS
# =============================================================================

func test_can_uncurse_with_valid_item() -> void:
	var uncurse: Array[String] = ["purify_scroll"]
	var item: ItemData = _create_cursed_item("Evil Sword", uncurse)

	assert_bool(item.can_uncurse_with("purify_scroll")).is_true()


func test_can_uncurse_with_invalid_item() -> void:
	var uncurse: Array[String] = ["purify_scroll"]
	var item: ItemData = _create_cursed_item("Evil Sword", uncurse)

	assert_bool(item.can_uncurse_with("random_item")).is_false()


func test_can_uncurse_with_non_cursed_item() -> void:
	var item: ItemData = _create_weapon()

	assert_bool(item.can_uncurse_with("purify_scroll")).is_false()


func test_requires_church_uncurse_when_no_items() -> void:
	var item: ItemData = _create_cursed_item("Evil Sword")
	# Empty uncurse_items array

	assert_bool(item.requires_church_uncurse()).is_true()


func test_requires_church_uncurse_false_when_items_exist() -> void:
	var uncurse: Array[String] = ["purify_scroll"]
	var item: ItemData = _create_cursed_item("Evil Sword", uncurse)

	assert_bool(item.requires_church_uncurse()).is_false()


func test_requires_church_uncurse_false_for_non_cursed() -> void:
	var item: ItemData = _create_weapon()

	assert_bool(item.requires_church_uncurse()).is_false()


# =============================================================================
# VALID SLOTS TESTS (Fallback Logic)
# =============================================================================

func test_get_default_valid_slots_for_sword() -> void:
	var item: ItemData = _create_weapon("Sword", "sword")
	var slots: Array[String] = item._get_default_valid_slots()

	assert_int(slots.size()).is_equal(1)
	assert_str(slots[0]).is_equal("weapon")


func test_get_default_valid_slots_for_ring() -> void:
	var item: ItemData = _create_ring()
	var slots: Array[String] = item._get_default_valid_slots()

	assert_int(slots.size()).is_equal(2)
	assert_bool("ring_1" in slots).is_true()
	assert_bool("ring_2" in slots).is_true()


func test_get_default_valid_slots_for_accessory() -> void:
	var item: ItemData = ItemData.new()
	item.item_name = "Amulet"
	item.item_type = ItemData.ItemType.ACCESSORY
	item.equipment_type = "accessory"
	item.equipment_slot = "accessory"

	var slots: Array[String] = item._get_default_valid_slots()

	assert_int(slots.size()).is_equal(1)
	assert_str(slots[0]).is_equal("accessory")


func test_get_default_valid_slots_for_unknown_type() -> void:
	var item: ItemData = ItemData.new()
	item.item_name = "Mystery"
	item.item_type = ItemData.ItemType.KEY
	item.equipment_type = "mystery"

	var slots: Array[String] = item._get_default_valid_slots()

	assert_int(slots.size()).is_equal(0)
