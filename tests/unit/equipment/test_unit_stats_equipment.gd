## Unit Tests for UnitStats Equipment Cache
##
## Tests equipment loading, weapon accessors, and effective stat calculations.
class_name TestUnitStatsEquipment
extends GdUnitTestSuite


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
	var stats: UnitStats = _create_unit_stats()
	stats.add_status_effect("attack_up", 3, 5)

	assert_int(stats.get_effective_strength()).is_equal(15)


func test_effective_strength_with_attack_down() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.add_status_effect("attack_down", 3, 3)

	assert_int(stats.get_effective_strength()).is_equal(7)


func test_effective_defense_with_defense_up() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.add_status_effect("defense_up", 3, 4)

	assert_int(stats.get_effective_defense()).is_equal(12)


func test_effective_defense_with_defense_down() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.add_status_effect("defense_down", 3, 2)

	assert_int(stats.get_effective_defense()).is_equal(6)


func test_effective_agility_with_speed_up() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.add_status_effect("speed_up", 3, 3)

	assert_int(stats.get_effective_agility()).is_equal(10)


func test_effective_agility_with_speed_down() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.add_status_effect("speed_down", 3, 2)

	assert_int(stats.get_effective_agility()).is_equal(5)


# =============================================================================
# COMBINED BONUS TESTS
# =============================================================================

func test_effective_strength_equipment_plus_buff() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.equipment_strength_bonus = 5
	stats.add_status_effect("attack_up", 3, 3)

	# Base 10 + Equipment 5 + Buff 3 = 18
	assert_int(stats.get_effective_strength()).is_equal(18)


func test_effective_defense_equipment_plus_debuff() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.equipment_defense_bonus = 4
	stats.add_status_effect("defense_down", 3, 2)

	# Base 8 + Equipment 4 - Debuff 2 = 10
	assert_int(stats.get_effective_defense()).is_equal(10)


func test_effective_stat_minimum_is_zero() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.strength = 5
	stats.add_status_effect("attack_down", 3, 10)  # Debuff exceeds base

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
