## Unit Tests for UnitStats Equipment Cache
##
## Tests equipment loading, weapon accessors, and effective stat calculations.
class_name TestUnitStatsEquipment
extends GdUnitTestSuite


const TEST_MOD_ID: String = "_test_unit_stats"


# =============================================================================
# TEST LIFECYCLE
# =============================================================================

func after_test() -> void:
	# Clean up any registered test status effects and items
	ModLoader.status_effect_registry.unregister_mod(TEST_MOD_ID)
	ModLoader.registry.clear_mod_resources(TEST_MOD_ID)


# =============================================================================
# TEST FIXTURES
# =============================================================================

func _create_unit_stats() -> UnitStats:
	var stats: UnitStats = UnitStats.new()
	stats.max_hp = 30
	stats.current_hp = 30
	stats.max_mp = 10
	stats.current_mp = 10
	stats.strength = 10
	stats.defense = 8
	stats.agility = 7
	stats.intelligence = 5
	stats.luck = 5
	stats.level = 5
	return stats


func _register_status_effect(effect_id: String, stat_modifiers: Dictionary) -> void:
	var effect: StatusEffectData = StatusEffectData.new()
	effect.effect_id = effect_id
	effect.display_name = effect_id.capitalize()
	effect.stat_modifiers = stat_modifiers
	ModLoader.status_effect_registry.register_effect(effect, TEST_MOD_ID)


func _create_and_register_item(
	item_id: String,
	item_type: ItemData.ItemType = ItemData.ItemType.WEAPON,
	modifiers: Dictionary = {}
) -> ItemData:
	var item: ItemData = ItemData.new()
	item.item_name = item_id.capitalize()
	item.item_type = item_type
	item.equipment_slot = "weapon" if item_type == ItemData.ItemType.WEAPON else "accessory"
	item.hp_modifier = modifiers.get("hp", 0)
	item.mp_modifier = modifiers.get("mp", 0)
	item.strength_modifier = modifiers.get("strength", 0)
	item.defense_modifier = modifiers.get("defense", 0)
	item.agility_modifier = modifiers.get("agility", 0)
	item.intelligence_modifier = modifiers.get("intelligence", 0)
	item.luck_modifier = modifiers.get("luck", 0)
	if item_type == ItemData.ItemType.WEAPON:
		item.attack_power = modifiers.get("attack_power", 10)
	if ModLoader and ModLoader.registry:
		ModLoader.registry.register_resource(item, "item", item_id, TEST_MOD_ID)
	return item


func _create_save_data_with_equipment(equipped_items: Array[Dictionary]) -> CharacterSaveData:
	var save_data: CharacterSaveData = CharacterSaveData.new()
	save_data.character_mod_id = TEST_MOD_ID
	save_data.character_resource_id = "test_char"
	save_data.fallback_character_name = "Test Character"
	save_data.fallback_class_name = "Fighter"
	save_data.level = 1
	save_data.current_hp = 20
	save_data.max_hp = 20
	save_data.equipped_items = equipped_items
	return save_data


# =============================================================================
# DEFAULT WEAPON ACCESSOR TESTS
# =============================================================================

func test_weapon_attack_power_no_weapon() -> void:
	var stats: UnitStats = _create_unit_stats()
	assert_int(stats.get_weapon_attack_power()).is_equal(0)


func test_weapon_range_no_weapon() -> void:
	var stats: UnitStats = _create_unit_stats()
	assert_int(stats.get_weapon_range()).is_equal(1)


func test_weapon_hit_rate_no_weapon() -> void:
	var stats: UnitStats = _create_unit_stats()
	assert_int(stats.get_weapon_hit_rate()).is_equal(90)


func test_weapon_crit_rate_no_weapon() -> void:
	var stats: UnitStats = _create_unit_stats()
	assert_int(stats.get_weapon_crit_rate()).is_equal(5)


# =============================================================================
# EFFECTIVE STAT TESTS (No Equipment)
# =============================================================================

func test_effective_strength_no_bonuses() -> void:
	var stats: UnitStats = _create_unit_stats()
	assert_int(stats.get_effective_strength()).is_equal(10)


func test_effective_defense_no_bonuses() -> void:
	var stats: UnitStats = _create_unit_stats()
	assert_int(stats.get_effective_defense()).is_equal(8)


func test_effective_agility_no_bonuses() -> void:
	var stats: UnitStats = _create_unit_stats()
	assert_int(stats.get_effective_agility()).is_equal(7)


func test_effective_intelligence_no_bonuses() -> void:
	var stats: UnitStats = _create_unit_stats()
	assert_int(stats.get_effective_intelligence()).is_equal(5)


func test_effective_luck_no_bonuses() -> void:
	var stats: UnitStats = _create_unit_stats()
	assert_int(stats.get_effective_luck()).is_equal(5)


func test_effective_max_hp_no_bonuses() -> void:
	var stats: UnitStats = _create_unit_stats()
	assert_int(stats.get_effective_max_hp()).is_equal(30)


func test_effective_max_mp_no_bonuses() -> void:
	var stats: UnitStats = _create_unit_stats()
	assert_int(stats.get_effective_max_mp()).is_equal(10)


# =============================================================================
# EFFECTIVE STAT TESTS (With Equipment Bonuses)
# =============================================================================

func test_effective_strength_with_bonus() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.equipment_strength_bonus = 5

	assert_int(stats.get_effective_strength()).is_equal(15)


func test_effective_defense_with_bonus() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.equipment_defense_bonus = 3

	assert_int(stats.get_effective_defense()).is_equal(11)


func test_effective_agility_with_bonus() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.equipment_agility_bonus = 2

	assert_int(stats.get_effective_agility()).is_equal(9)


func test_effective_intelligence_with_bonus() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.equipment_intelligence_bonus = 4

	assert_int(stats.get_effective_intelligence()).is_equal(9)


func test_effective_luck_with_bonus() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.equipment_luck_bonus = 2

	assert_int(stats.get_effective_luck()).is_equal(7)


func test_effective_max_hp_with_bonus() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.equipment_hp_bonus = 10

	assert_int(stats.get_effective_max_hp()).is_equal(40)


func test_effective_max_mp_with_bonus() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.equipment_mp_bonus = 5

	assert_int(stats.get_effective_max_mp()).is_equal(15)


# =============================================================================
# EFFECTIVE STAT TESTS (With Status Effects)
# =============================================================================

func test_effective_strength_with_attack_up() -> void:
	_register_status_effect("attack_up", {"strength": 5})
	var stats: UnitStats = _create_unit_stats()
	stats.add_status_effect("attack_up", 3)

	assert_int(stats.get_effective_strength()).is_equal(15)


func test_effective_strength_with_attack_down() -> void:
	_register_status_effect("attack_down", {"strength": -3})
	var stats: UnitStats = _create_unit_stats()
	stats.add_status_effect("attack_down", 3)

	assert_int(stats.get_effective_strength()).is_equal(7)


func test_effective_defense_with_defense_up() -> void:
	_register_status_effect("defense_up", {"defense": 4})
	var stats: UnitStats = _create_unit_stats()
	stats.add_status_effect("defense_up", 3)

	assert_int(stats.get_effective_defense()).is_equal(12)


func test_effective_defense_with_defense_down() -> void:
	_register_status_effect("defense_down", {"defense": -2})
	var stats: UnitStats = _create_unit_stats()
	stats.add_status_effect("defense_down", 3)

	assert_int(stats.get_effective_defense()).is_equal(6)


func test_effective_agility_with_speed_up() -> void:
	_register_status_effect("speed_up", {"agility": 3})
	var stats: UnitStats = _create_unit_stats()
	stats.add_status_effect("speed_up", 3)

	assert_int(stats.get_effective_agility()).is_equal(10)


func test_effective_agility_with_speed_down() -> void:
	_register_status_effect("speed_down", {"agility": -2})
	var stats: UnitStats = _create_unit_stats()
	stats.add_status_effect("speed_down", 3)

	assert_int(stats.get_effective_agility()).is_equal(5)


# =============================================================================
# COMBINED BONUS TESTS
# =============================================================================

func test_effective_strength_equipment_plus_buff() -> void:
	_register_status_effect("attack_up", {"strength": 3})
	var stats: UnitStats = _create_unit_stats()
	stats.equipment_strength_bonus = 5
	stats.add_status_effect("attack_up", 3)

	# Base 10 + Equipment 5 + Buff 3 = 18
	assert_int(stats.get_effective_strength()).is_equal(18)


func test_effective_defense_equipment_plus_debuff() -> void:
	_register_status_effect("defense_down", {"defense": -2})
	var stats: UnitStats = _create_unit_stats()
	stats.equipment_defense_bonus = 4
	stats.add_status_effect("defense_down", 3)

	# Base 8 + Equipment 4 - Debuff 2 = 10
	assert_int(stats.get_effective_defense()).is_equal(10)


func test_effective_stat_minimum_is_zero() -> void:
	_register_status_effect("attack_down", {"strength": -10})
	var stats: UnitStats = _create_unit_stats()
	stats.strength = 5
	stats.add_status_effect("attack_down", 3)

	# Should clamp to 0, not go negative
	assert_int(stats.get_effective_strength()).is_equal(0)


# =============================================================================
# EQUIPMENT CACHE CLEARING TESTS
# =============================================================================

func test_equipment_cache_starts_empty() -> void:
	var stats: UnitStats = _create_unit_stats()

	assert_object(stats.cached_weapon).is_null()
	assert_int(stats.cached_equipment.size()).is_equal(0)
	assert_int(stats.equipment_strength_bonus).is_equal(0)


# =============================================================================
# EQUIPMENT WORKFLOW TESTS (Full Item -> Equip -> Stat Bonus Pipeline)
# =============================================================================

func test_item_registry_lookup_works() -> void:
	# Debug test to verify registry registration and lookup work
	var item: ItemData = _create_and_register_item("debug_test_item", ItemData.ItemType.WEAPON, {"strength": 5})

	# Check if ModLoader and registry exist
	assert_bool(ModLoader != null).is_true()
	assert_bool(ModLoader.registry != null).is_true()

	# Try to retrieve the item
	var retrieved: ItemData = ModLoader.registry.get_item("debug_test_item")
	assert_object(retrieved).is_not_null()
	assert_int(retrieved.strength_modifier).is_equal(5)


func test_equip_weapon_applies_strength_bonus() -> void:
	_create_and_register_item("test_sword", ItemData.ItemType.WEAPON, {"strength": 5})
	var save_data: CharacterSaveData = _create_save_data_with_equipment([
		{"slot": "weapon", "item_id": "test_sword", "curse_broken": false}
	])
	var stats: UnitStats = _create_unit_stats()

	stats.load_equipment_from_save(save_data)

	assert_int(stats.equipment_strength_bonus).is_equal(5)
	assert_int(stats.get_effective_strength()).is_equal(15)  # Base 10 + 5


func test_equip_weapon_applies_defense_bonus() -> void:
	_create_and_register_item("test_shield_sword", ItemData.ItemType.WEAPON, {"defense": 3})
	var save_data: CharacterSaveData = _create_save_data_with_equipment([
		{"slot": "weapon", "item_id": "test_shield_sword", "curse_broken": false}
	])
	var stats: UnitStats = _create_unit_stats()

	stats.load_equipment_from_save(save_data)

	assert_int(stats.equipment_defense_bonus).is_equal(3)
	assert_int(stats.get_effective_defense()).is_equal(11)  # Base 8 + 3


func test_equip_accessory_applies_multiple_bonuses() -> void:
	_create_and_register_item("test_ring", ItemData.ItemType.ACCESSORY, {
		"strength": 2,
		"agility": 3,
		"luck": 1
	})
	var save_data: CharacterSaveData = _create_save_data_with_equipment([
		{"slot": "accessory", "item_id": "test_ring", "curse_broken": false}
	])
	var stats: UnitStats = _create_unit_stats()

	stats.load_equipment_from_save(save_data)

	assert_int(stats.equipment_strength_bonus).is_equal(2)
	assert_int(stats.equipment_agility_bonus).is_equal(3)
	assert_int(stats.equipment_luck_bonus).is_equal(1)
	assert_int(stats.get_effective_strength()).is_equal(12)  # Base 10 + 2
	assert_int(stats.get_effective_agility()).is_equal(10)   # Base 7 + 3
	assert_int(stats.get_effective_luck()).is_equal(6)       # Base 5 + 1


func test_equip_multiple_items_stacks_bonuses() -> void:
	_create_and_register_item("test_weapon", ItemData.ItemType.WEAPON, {"strength": 4})
	_create_and_register_item("test_armor", ItemData.ItemType.ACCESSORY, {"defense": 3, "hp": 10})
	_create_and_register_item("test_amulet", ItemData.ItemType.ACCESSORY, {"intelligence": 5, "mp": 8})
	var save_data: CharacterSaveData = _create_save_data_with_equipment([
		{"slot": "weapon", "item_id": "test_weapon", "curse_broken": false},
		{"slot": "armor", "item_id": "test_armor", "curse_broken": false},
		{"slot": "accessory", "item_id": "test_amulet", "curse_broken": false}
	])
	var stats: UnitStats = _create_unit_stats()

	stats.load_equipment_from_save(save_data)

	assert_int(stats.equipment_strength_bonus).is_equal(4)
	assert_int(stats.equipment_defense_bonus).is_equal(3)
	assert_int(stats.equipment_hp_bonus).is_equal(10)
	assert_int(stats.equipment_intelligence_bonus).is_equal(5)
	assert_int(stats.equipment_mp_bonus).is_equal(8)
	assert_int(stats.get_effective_strength()).is_equal(14)       # Base 10 + 4
	assert_int(stats.get_effective_defense()).is_equal(11)        # Base 8 + 3
	assert_int(stats.get_effective_max_hp()).is_equal(40)         # Base 30 + 10
	assert_int(stats.get_effective_intelligence()).is_equal(10)   # Base 5 + 5
	assert_int(stats.get_effective_max_mp()).is_equal(18)         # Base 10 + 8


func test_equip_item_with_negative_modifier() -> void:
	# Cursed items might have stat penalties
	_create_and_register_item("cursed_blade", ItemData.ItemType.WEAPON, {
		"strength": 8,
		"luck": -3
	})
	var save_data: CharacterSaveData = _create_save_data_with_equipment([
		{"slot": "weapon", "item_id": "cursed_blade", "curse_broken": false}
	])
	var stats: UnitStats = _create_unit_stats()

	stats.load_equipment_from_save(save_data)

	assert_int(stats.equipment_strength_bonus).is_equal(8)
	assert_int(stats.equipment_luck_bonus).is_equal(-3)
	assert_int(stats.get_effective_strength()).is_equal(18)  # Base 10 + 8
	assert_int(stats.get_effective_luck()).is_equal(2)       # Base 5 - 3


func test_equip_weapon_caches_weapon_reference() -> void:
	var weapon: ItemData = _create_and_register_item("cached_sword", ItemData.ItemType.WEAPON, {
		"attack_power": 15
	})
	var save_data: CharacterSaveData = _create_save_data_with_equipment([
		{"slot": "weapon", "item_id": "cached_sword", "curse_broken": false}
	])
	var stats: UnitStats = _create_unit_stats()

	stats.load_equipment_from_save(save_data)

	assert_object(stats.cached_weapon).is_not_null()
	assert_int(stats.get_weapon_attack_power()).is_equal(15)


func test_load_equipment_clears_previous_bonuses() -> void:
	_create_and_register_item("old_sword", ItemData.ItemType.WEAPON, {"strength": 10})
	_create_and_register_item("new_sword", ItemData.ItemType.WEAPON, {"strength": 3})
	var stats: UnitStats = _create_unit_stats()

	# First load with old sword
	var old_save: CharacterSaveData = _create_save_data_with_equipment([
		{"slot": "weapon", "item_id": "old_sword", "curse_broken": false}
	])
	stats.load_equipment_from_save(old_save)
	assert_int(stats.equipment_strength_bonus).is_equal(10)

	# Load again with new sword - should replace, not stack
	var new_save: CharacterSaveData = _create_save_data_with_equipment([
		{"slot": "weapon", "item_id": "new_sword", "curse_broken": false}
	])
	stats.load_equipment_from_save(new_save)

	assert_int(stats.equipment_strength_bonus).is_equal(3)
	assert_int(stats.get_effective_strength()).is_equal(13)  # Base 10 + 3, not 10 + 10 + 3


func test_equipment_plus_status_effect_full_workflow() -> void:
	# Test the complete pipeline: item bonuses + status effect bonuses
	_create_and_register_item("power_sword", ItemData.ItemType.WEAPON, {"strength": 5})
	_register_status_effect("boost", {"strength": 3})
	var save_data: CharacterSaveData = _create_save_data_with_equipment([
		{"slot": "weapon", "item_id": "power_sword", "curse_broken": false}
	])
	var stats: UnitStats = _create_unit_stats()

	stats.load_equipment_from_save(save_data)
	stats.add_status_effect("boost", 3)

	# Base 10 + Equipment 5 + Status Effect 3 = 18
	assert_int(stats.get_effective_strength()).is_equal(18)


# =============================================================================
# CORE STATS OPERATIONS TESTS
# =============================================================================

func test_unit_stats_creation() -> void:
	var stats: UnitStats = UnitStats.new()
	stats.strength = 15
	stats.defense = 10
	stats.agility = 12
	stats.intelligence = 8
	stats.luck = 6

	assert_int(stats.strength).is_equal(15)
	assert_int(stats.defense).is_equal(10)
	assert_int(stats.agility).is_equal(12)
	assert_int(stats.intelligence).is_equal(8)
	assert_int(stats.luck).is_equal(6)


func test_unit_stats_take_damage() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.max_hp = 20
	stats.current_hp = 20

	var died: bool = stats.take_damage(5)

	assert_int(stats.current_hp).is_equal(15)
	assert_bool(died).is_false()


func test_unit_stats_take_fatal_damage() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.max_hp = 20
	stats.current_hp = 10

	var died: bool = stats.take_damage(15)

	assert_int(stats.current_hp).is_equal(0)
	assert_bool(died).is_true()


func test_unit_stats_heal() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.max_hp = 20
	stats.current_hp = 10

	stats.heal(5)

	assert_int(stats.current_hp).is_equal(15)


func test_unit_stats_heal_over_max() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.max_hp = 20
	stats.current_hp = 18

	stats.heal(10)

	assert_int(stats.current_hp).is_equal(20)


func test_unit_stats_spend_mp() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.max_mp = 10
	stats.current_mp = 10

	var success: bool = stats.spend_mp(3)

	assert_bool(success).is_true()
	assert_int(stats.current_mp).is_equal(7)


func test_unit_stats_spend_mp_insufficient() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.max_mp = 10
	stats.current_mp = 5

	var success: bool = stats.spend_mp(10)

	assert_bool(success).is_false()
	assert_int(stats.current_mp).is_equal(5)


func test_unit_stats_status_effect_add() -> void:
	var stats: UnitStats = _create_unit_stats()

	stats.add_status_effect("poison", 3, 5)

	assert_int(stats.status_effects.size()).is_equal(1)


func test_unit_stats_status_effect_has() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.add_status_effect("poison", 3, 5)

	assert_bool(stats.has_status_effect("poison")).is_true()
	assert_bool(stats.has_status_effect("stun")).is_false()


func test_unit_stats_status_effect_remove() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.add_status_effect("poison", 3, 5)

	stats.remove_status_effect("poison")

	assert_bool(stats.has_status_effect("poison")).is_false()


func test_unit_stats_hp_percent() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.max_hp = 100
	stats.current_hp = 75

	var percent: float = stats.get_hp_percent()

	assert_float(percent).is_equal(0.75)
