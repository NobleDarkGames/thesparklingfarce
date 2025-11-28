## Unit Tests for CombatCalculator
##
## Tests all combat formulas following Shining Force-inspired mechanics.
## Pure calculation tests - no scene dependencies.
class_name TestCombatCalculator
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

## Create a UnitStats with specified combat stats
func _create_test_stats(
	str_val: int = 10,
	def_val: int = 5,
	agi_val: int = 10,
	int_val: int = 10,
	luck_val: int = 5
) -> UnitStats:
	var stats: UnitStats = UnitStats.new()
	stats.strength = str_val
	stats.defense = def_val
	stats.agility = agi_val
	stats.intelligence = int_val
	stats.luck = luck_val
	stats.level = 1
	return stats


## Create a mock ability resource with base_power
func _create_test_ability(power: int) -> Resource:
	var ability: Resource = Resource.new()
	ability.set_meta("base_power", power)
	# gdUnit4 doesn't have easy property mocking, so we use a simple approach
	# The CombatCalculator checks "if 'base_power' in ability"
	# We need to use a real AbilityData or create a simple script
	return ability


# =============================================================================
# PHYSICAL DAMAGE TESTS
# =============================================================================

func test_physical_damage_basic_calculation() -> void:
	# STR 20 vs DEF 10 should give base damage of 10
	var attacker: UnitStats = _create_test_stats(20, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 10, 10, 10, 5)

	# Run multiple times to account for variance (0.9 to 1.1)
	# Base damage = 20 - 10 = 10
	# With variance: 9 to 11
	for i in range(20):
		var damage: int = CombatCalculator.calculate_physical_damage(attacker, defender)
		assert_int(damage).is_between(9, 11)


func test_physical_damage_minimum_is_one() -> void:
	# STR 5 vs DEF 20 would be negative, but minimum should be 1
	var attacker: UnitStats = _create_test_stats(5, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 20, 10, 10, 5)

	for i in range(10):
		var damage: int = CombatCalculator.calculate_physical_damage(attacker, defender)
		assert_int(damage).is_equal(1)


func test_physical_damage_high_strength() -> void:
	# STR 50 vs DEF 10 = 40 base damage
	# With variance: 36 to 44
	var attacker: UnitStats = _create_test_stats(50, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 10, 10, 10, 5)

	for i in range(20):
		var damage: int = CombatCalculator.calculate_physical_damage(attacker, defender)
		assert_int(damage).is_between(36, 44)


func test_physical_damage_null_attacker_returns_zero() -> void:
	var defender: UnitStats = _create_test_stats()
	var damage: int = CombatCalculator.calculate_physical_damage(null, defender)
	assert_int(damage).is_equal(0)


func test_physical_damage_null_defender_returns_zero() -> void:
	var attacker: UnitStats = _create_test_stats()
	var damage: int = CombatCalculator.calculate_physical_damage(attacker, null)
	assert_int(damage).is_equal(0)


func test_physical_damage_equal_stats() -> void:
	# STR 15 vs DEF 15 = 0 base, minimum 1
	var attacker: UnitStats = _create_test_stats(15, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 15, 10, 10, 5)

	for i in range(10):
		var damage: int = CombatCalculator.calculate_physical_damage(attacker, defender)
		assert_int(damage).is_equal(1)


# =============================================================================
# HIT CHANCE TESTS
# =============================================================================

func test_hit_chance_base_is_80() -> void:
	# Equal AGI should give base 80%
	var attacker: UnitStats = _create_test_stats(10, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 5, 10, 10, 5)

	var hit_chance: int = CombatCalculator.calculate_hit_chance(attacker, defender)
	assert_int(hit_chance).is_equal(80)


func test_hit_chance_agility_advantage() -> void:
	# AGI 20 vs AGI 10 = +20% hit chance (80 + 10*2 = 100, clamped to 99)
	var attacker: UnitStats = _create_test_stats(10, 5, 20, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 5, 10, 10, 5)

	var hit_chance: int = CombatCalculator.calculate_hit_chance(attacker, defender)
	assert_int(hit_chance).is_equal(99)  # Clamped at 99


func test_hit_chance_agility_disadvantage() -> void:
	# AGI 10 vs AGI 20 = -20% hit chance (80 - 10*2 = 60)
	var attacker: UnitStats = _create_test_stats(10, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 5, 20, 10, 5)

	var hit_chance: int = CombatCalculator.calculate_hit_chance(attacker, defender)
	assert_int(hit_chance).is_equal(60)


func test_hit_chance_minimum_is_10() -> void:
	# AGI 5 vs AGI 50 = 80 + (5-50)*2 = 80 - 90 = -10, clamped to 10
	var attacker: UnitStats = _create_test_stats(10, 5, 5, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 5, 50, 10, 5)

	var hit_chance: int = CombatCalculator.calculate_hit_chance(attacker, defender)
	assert_int(hit_chance).is_equal(10)


func test_hit_chance_maximum_is_99() -> void:
	# AGI 50 vs AGI 5 = 80 + (50-5)*2 = 80 + 90 = 170, clamped to 99
	var attacker: UnitStats = _create_test_stats(10, 5, 50, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 5, 5, 10, 5)

	var hit_chance: int = CombatCalculator.calculate_hit_chance(attacker, defender)
	assert_int(hit_chance).is_equal(99)


func test_hit_chance_null_returns_50() -> void:
	var attacker: UnitStats = _create_test_stats()
	var hit_chance: int = CombatCalculator.calculate_hit_chance(attacker, null)
	assert_int(hit_chance).is_equal(50)


# =============================================================================
# CRIT CHANCE TESTS
# =============================================================================

func test_crit_chance_base_is_5() -> void:
	# Equal LUK should give base 5%
	var attacker: UnitStats = _create_test_stats(10, 5, 10, 10, 10)
	var defender: UnitStats = _create_test_stats(10, 5, 10, 10, 10)

	var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker, defender)
	assert_int(crit_chance).is_equal(5)


func test_crit_chance_luck_advantage() -> void:
	# LUK 30 vs LUK 10 = 5 + 20 = 25%
	var attacker: UnitStats = _create_test_stats(10, 5, 10, 10, 30)
	var defender: UnitStats = _create_test_stats(10, 5, 10, 10, 10)

	var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker, defender)
	assert_int(crit_chance).is_equal(25)


func test_crit_chance_luck_disadvantage() -> void:
	# LUK 5 vs LUK 15 = 5 - 10 = -5, clamped to 0
	var attacker: UnitStats = _create_test_stats(10, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 5, 10, 10, 15)

	var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker, defender)
	assert_int(crit_chance).is_equal(0)


func test_crit_chance_maximum_is_50() -> void:
	# LUK 100 vs LUK 10 = 5 + 90 = 95, clamped to 50
	var attacker: UnitStats = _create_test_stats(10, 5, 10, 10, 100)
	var defender: UnitStats = _create_test_stats(10, 5, 10, 10, 10)

	var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker, defender)
	assert_int(crit_chance).is_equal(50)


func test_crit_chance_minimum_is_0() -> void:
	# LUK 5 vs LUK 50 = 5 - 45 = -40, clamped to 0
	var attacker: UnitStats = _create_test_stats(10, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 5, 10, 10, 50)

	var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker, defender)
	assert_int(crit_chance).is_equal(0)


func test_crit_chance_null_returns_zero() -> void:
	var attacker: UnitStats = _create_test_stats()
	var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker, null)
	assert_int(crit_chance).is_equal(0)


# =============================================================================
# ROLL TESTS (Probabilistic - test return type and bounds)
# =============================================================================

func test_roll_hit_returns_bool() -> void:
	var result: bool = CombatCalculator.roll_hit(50)
	assert_bool(result is bool).is_true()


func test_roll_hit_100_percent_always_hits() -> void:
	# 100% hit chance (though clamped at 99 in practice)
	for i in range(20):
		var result: bool = CombatCalculator.roll_hit(100)
		assert_bool(result).is_true()


func test_roll_hit_0_percent_never_hits() -> void:
	# 0% hit chance should never hit
	for i in range(20):
		var result: bool = CombatCalculator.roll_hit(0)
		assert_bool(result).is_false()


func test_roll_crit_returns_bool() -> void:
	var result: bool = CombatCalculator.roll_crit(25)
	assert_bool(result is bool).is_true()


func test_roll_crit_100_percent_always_crits() -> void:
	for i in range(20):
		var result: bool = CombatCalculator.roll_crit(100)
		assert_bool(result).is_true()


func test_roll_crit_0_percent_never_crits() -> void:
	for i in range(20):
		var result: bool = CombatCalculator.roll_crit(0)
		assert_bool(result).is_false()


# =============================================================================
# EXPERIENCE GAIN TESTS
# =============================================================================

func test_experience_gain_same_level() -> void:
	# Same level = base XP (multiplier 1.0)
	var xp: int = CombatCalculator.calculate_experience_gain(5, 5, 10)
	assert_int(xp).is_equal(10)


func test_experience_gain_higher_enemy() -> void:
	# Enemy 2 levels higher = 1.0 + 2*0.2 = 1.4 multiplier
	# 10 * 1.4 = 14
	var xp: int = CombatCalculator.calculate_experience_gain(5, 7, 10)
	assert_int(xp).is_equal(14)


func test_experience_gain_lower_enemy() -> void:
	# Enemy 3 levels lower = 1.0 - 3*0.1 = 0.7 multiplier
	# 10 * 0.7 = 7
	var xp: int = CombatCalculator.calculate_experience_gain(5, 2, 10)
	assert_int(xp).is_equal(7)


func test_experience_gain_minimum_multiplier() -> void:
	# Enemy 10 levels lower = 1.0 - 10*0.1 = 0.0, but min is 0.5
	# 10 * 0.5 = 5
	var xp: int = CombatCalculator.calculate_experience_gain(15, 5, 10)
	assert_int(xp).is_equal(5)


func test_experience_gain_minimum_is_one() -> void:
	# Even with low base XP and penalty, minimum should be 1
	var xp: int = CombatCalculator.calculate_experience_gain(20, 1, 1)
	assert_int(xp).is_greater_equal(1)


func test_experience_gain_default_base_xp() -> void:
	# Default base_xp is 10
	var xp: int = CombatCalculator.calculate_experience_gain(5, 5)
	assert_int(xp).is_equal(10)


# =============================================================================
# COUNTER DAMAGE TESTS
# =============================================================================

func test_counter_damage_is_75_percent() -> void:
	# Counter damage = normal damage * 0.75
	var defender: UnitStats = _create_test_stats(20, 5, 10, 10, 5)
	var attacker: UnitStats = _create_test_stats(10, 10, 10, 10, 5)

	# Base damage = 20 - 10 = 10, counter = 7 (int(10 * 0.75) to int(10 * 1.1 * 0.75))
	# With variance: 6 to 8 (approximately)
	for i in range(20):
		var counter_dmg: int = CombatCalculator.calculate_counter_damage(defender, attacker, true)
		assert_int(counter_dmg).is_between(6, 9)


func test_counter_damage_returns_zero_when_cannot_counter() -> void:
	var defender: UnitStats = _create_test_stats(20, 5, 10, 10, 5)
	var attacker: UnitStats = _create_test_stats(10, 10, 10, 10, 5)

	var counter_dmg: int = CombatCalculator.calculate_counter_damage(defender, attacker, false)
	assert_int(counter_dmg).is_equal(0)


# =============================================================================
# COUNTERATTACK ELIGIBILITY TESTS
# =============================================================================

func test_can_counterattack_melee_vs_melee() -> void:
	# Weapon range 1, attack distance 1 - can counter
	var can_counter: bool = CombatCalculator.can_counterattack(1, 1)
	assert_bool(can_counter).is_true()


func test_cannot_counterattack_melee_vs_ranged() -> void:
	# Weapon range 1, attack distance 3 - cannot counter
	var can_counter: bool = CombatCalculator.can_counterattack(1, 3)
	assert_bool(can_counter).is_false()


func test_can_counterattack_ranged_vs_melee() -> void:
	# Weapon range 3, attack distance 1 - can counter (range >= distance)
	var can_counter: bool = CombatCalculator.can_counterattack(3, 1)
	assert_bool(can_counter).is_true()


func test_can_counterattack_ranged_vs_ranged() -> void:
	# Weapon range 3, attack distance 3 - can counter
	var can_counter: bool = CombatCalculator.can_counterattack(3, 3)
	assert_bool(can_counter).is_true()


func test_cannot_counterattack_short_range_vs_long() -> void:
	# Weapon range 2, attack distance 4 - cannot counter
	var can_counter: bool = CombatCalculator.can_counterattack(2, 4)
	assert_bool(can_counter).is_false()
