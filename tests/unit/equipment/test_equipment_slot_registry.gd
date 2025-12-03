## Unit Tests for EquipmentSlotRegistry
##
## Tests data-driven equipment slot system for SF-style and custom layouts.
class_name TestEquipmentSlotRegistry
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _registry: EquipmentSlotRegistry


func before_test() -> void:
	_registry = EquipmentSlotRegistry.new()


# =============================================================================
# DEFAULT SLOTS TESTS
# =============================================================================

func test_default_slots_count() -> void:
	var slots: Array[Dictionary] = _registry.get_slots()
	assert_int(slots.size()).is_equal(4)


func test_default_slots_have_weapon() -> void:
	assert_bool(_registry.is_valid_slot("weapon")).is_true()


func test_default_slots_have_ring_1() -> void:
	assert_bool(_registry.is_valid_slot("ring_1")).is_true()


func test_default_slots_have_ring_2() -> void:
	assert_bool(_registry.is_valid_slot("ring_2")).is_true()


func test_default_slots_have_accessory() -> void:
	assert_bool(_registry.is_valid_slot("accessory")).is_true()


func test_invalid_slot_returns_false() -> void:
	assert_bool(_registry.is_valid_slot("helmet")).is_false()


func test_slot_ids_returns_all_default_ids() -> void:
	var ids: Array[String] = _registry.get_slot_ids()
	assert_int(ids.size()).is_equal(4)
	assert_bool("weapon" in ids).is_true()
	assert_bool("ring_1" in ids).is_true()
	assert_bool("ring_2" in ids).is_true()
	assert_bool("accessory" in ids).is_true()


# =============================================================================
# SLOT TYPE ACCEPTANCE TESTS
# =============================================================================

func test_weapon_slot_accepts_weapon_type() -> void:
	assert_bool(_registry.slot_accepts_type("weapon", "weapon")).is_true()


func test_weapon_slot_rejects_ring_type() -> void:
	assert_bool(_registry.slot_accepts_type("weapon", "ring")).is_false()


func test_ring_1_accepts_ring_type() -> void:
	assert_bool(_registry.slot_accepts_type("ring_1", "ring")).is_true()


func test_ring_2_accepts_ring_type() -> void:
	assert_bool(_registry.slot_accepts_type("ring_2", "ring")).is_true()


func test_accessory_accepts_accessory_type() -> void:
	assert_bool(_registry.slot_accepts_type("accessory", "accessory")).is_true()


func test_invalid_slot_rejects_all_types() -> void:
	assert_bool(_registry.slot_accepts_type("helmet", "weapon")).is_false()


# =============================================================================
# SLOTS FOR TYPE TESTS
# =============================================================================

func test_get_slots_for_weapon_type() -> void:
	var slots: Array[String] = _registry.get_slots_for_type("weapon")
	assert_int(slots.size()).is_equal(1)
	assert_str(slots[0]).is_equal("weapon")


func test_get_slots_for_ring_type() -> void:
	var slots: Array[String] = _registry.get_slots_for_type("ring")
	assert_int(slots.size()).is_equal(2)
	assert_bool("ring_1" in slots).is_true()
	assert_bool("ring_2" in slots).is_true()


func test_get_slots_for_unknown_type() -> void:
	var slots: Array[String] = _registry.get_slots_for_type("laser")
	assert_int(slots.size()).is_equal(0)


# =============================================================================
# DISPLAY NAME TESTS
# =============================================================================

func test_get_slot_display_name_weapon() -> void:
	assert_str(_registry.get_slot_display_name("weapon")).is_equal("Weapon")


func test_get_slot_display_name_ring_1() -> void:
	assert_str(_registry.get_slot_display_name("ring_1")).is_equal("Ring 1")


func test_get_slot_display_name_unknown_slot_capitalizes() -> void:
	var name: String = _registry.get_slot_display_name("unknown_slot")
	assert_str(name).is_equal("Unknown_slot")


# =============================================================================
# CUSTOM SLOT LAYOUT TESTS
# =============================================================================

func test_register_custom_slot_layout() -> void:
	var custom_slots: Array[Dictionary] = [
		{"id": "main_hand", "display_name": "Main Hand", "accepts_types": ["weapon"]},
		{"id": "off_hand", "display_name": "Off Hand", "accepts_types": ["shield", "weapon"]},
		{"id": "helmet", "display_name": "Helmet", "accepts_types": ["helmet"]}
	]

	_registry.register_slot_layout("test_mod", custom_slots)

	assert_int(_registry.get_slot_count()).is_equal(3)
	assert_bool(_registry.is_valid_slot("main_hand")).is_true()
	assert_bool(_registry.is_valid_slot("helmet")).is_true()
	assert_bool(_registry.is_valid_slot("weapon")).is_false()  # Default slot replaced


func test_custom_layout_source_mod() -> void:
	var custom_slots: Array[Dictionary] = [
		{"id": "implant", "display_name": "Implant", "accepts_types": ["implant"]}
	]

	_registry.register_slot_layout("scifi_mod", custom_slots)

	assert_str(_registry.get_source_mod()).is_equal("scifi_mod")


func test_custom_layout_accepts_types() -> void:
	var custom_slots: Array[Dictionary] = [
		{"id": "off_hand", "display_name": "Off Hand", "accepts_types": ["shield", "weapon"]}
	]

	_registry.register_slot_layout("test_mod", custom_slots)

	assert_bool(_registry.slot_accepts_type("off_hand", "shield")).is_true()
	assert_bool(_registry.slot_accepts_type("off_hand", "weapon")).is_true()
	assert_bool(_registry.slot_accepts_type("off_hand", "ring")).is_false()


func test_clear_mod_registrations_restores_defaults() -> void:
	var custom_slots: Array[Dictionary] = [
		{"id": "helmet", "display_name": "Helmet", "accepts_types": ["helmet"]}
	]
	_registry.register_slot_layout("test_mod", custom_slots)

	_registry.clear_mod_registrations()

	assert_int(_registry.get_slot_count()).is_equal(4)
	assert_bool(_registry.is_valid_slot("weapon")).is_true()
	assert_bool(_registry.is_valid_slot("helmet")).is_false()


# =============================================================================
# CASE INSENSITIVITY TESTS
# =============================================================================

func test_slot_lookup_is_case_insensitive() -> void:
	assert_bool(_registry.is_valid_slot("WEAPON")).is_true()
	assert_bool(_registry.is_valid_slot("Weapon")).is_true()
	assert_bool(_registry.is_valid_slot("weapon")).is_true()


func test_type_lookup_is_case_insensitive() -> void:
	assert_bool(_registry.slot_accepts_type("weapon", "WEAPON")).is_true()
	assert_bool(_registry.slot_accepts_type("WEAPON", "weapon")).is_true()
