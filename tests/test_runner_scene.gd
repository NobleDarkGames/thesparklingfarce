## Headless Test Runner for Sparkling Farce (Scene-based)
##
## Runs unit tests after autoloads are initialized.
## Must be run as a scene, not a script.
##
## Usage: godot --headless res://tests/test_runner_scene.tscn
extends Node


## Test results tracking
var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []
var _current_test_suite: String = ""
var _current_test: String = ""


func _ready() -> void:
	# Wait one frame to ensure all autoloads are ready
	await get_tree().process_frame

	print("\n" + "=".repeat(60))
	print("SPARKLING FARCE - UNIT TEST RUNNER")
	print("=".repeat(60) + "\n")

	# Run all test suites
	_run_combat_calculator_tests()
	_run_grid_tests()
	_run_unit_stats_tests()
	_run_experience_config_tests()
	_run_item_menu_integration_tests()

	# Print summary
	_print_summary()

	# Exit with appropriate code
	get_tree().quit(0 if _failed == 0 else 1)


func _print_summary() -> void:
	print("\n" + "=".repeat(60))
	print("TEST SUMMARY")
	print("=".repeat(60))
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)

	if _errors.size() > 0:
		print("\nFailed Tests:")
		for error: String in _errors:
			print("  - %s" % error)

	print("=".repeat(60))

	if _failed == 0:
		print("ALL TESTS PASSED!")
	else:
		print("SOME TESTS FAILED!")

	print("=".repeat(60) + "\n")


# =============================================================================
# ASSERTION HELPERS
# =============================================================================

func _start_suite(name: String) -> void:
	_current_test_suite = name
	print("\n--- Test Suite: %s ---" % name)


func _start_test(name: String) -> void:
	_current_test = name


func _pass() -> void:
	_passed += 1
	print("  [PASS] %s" % _current_test)


func _fail(message: String) -> void:
	_failed += 1
	var error_msg: String = "%s::%s - %s" % [_current_test_suite, _current_test, message]
	_errors.append(error_msg)
	print("  [FAIL] %s: %s" % [_current_test, message])


func _assert_equal(actual: Variant, expected: Variant, context: String = "") -> bool:
	if actual == expected:
		return true
	else:
		var msg: String = "Expected %s but got %s" % [expected, actual]
		if context != "":
			msg += " (%s)" % context
		_fail(msg)
		return false


func _assert_between(actual: int, min_val: int, max_val: int, context: String = "") -> bool:
	if actual >= min_val and actual <= max_val:
		return true
	else:
		var msg: String = "Expected %d to be between %d and %d" % [actual, min_val, max_val]
		if context != "":
			msg += " (%s)" % context
		_fail(msg)
		return false


func _assert_true(condition: bool, context: String = "") -> bool:
	if condition:
		return true
	else:
		var msg: String = "Expected true but got false"
		if context != "":
			msg += " (%s)" % context
		_fail(msg)
		return false


func _assert_false(condition: bool, context: String = "") -> bool:
	if not condition:
		return true
	else:
		var msg: String = "Expected false but got true"
		if context != "":
			msg += " (%s)" % context
		_fail(msg)
		return false


func _assert_greater_equal(actual: int, expected: int, context: String = "") -> bool:
	if actual >= expected:
		return true
	else:
		var msg: String = "Expected %d >= %d" % [actual, expected]
		if context != "":
			msg += " (%s)" % context
		_fail(msg)
		return false


func _assert_not_null(value: Variant, context: String = "") -> bool:
	if value != null:
		return true
	else:
		var msg: String = "Expected non-null value"
		if context != "":
			msg += " (%s)" % context
		_fail(msg)
		return false


# =============================================================================
# TEST FIXTURES
# =============================================================================

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
	stats.max_hp = 20
	stats.current_hp = 20
	stats.max_mp = 10
	stats.current_mp = 10
	return stats


## Create UnitStats with a ClassData attached for counter rate testing
func _create_test_stats_with_class(counter_rate: int = 12) -> UnitStats:
	var stats: UnitStats = UnitStats.new()
	stats.strength = 10
	stats.defense = 5
	stats.agility = 10
	stats.intelligence = 10
	stats.luck = 5
	stats.level = 1
	stats.max_hp = 20
	stats.current_hp = 20
	stats.max_mp = 10
	stats.current_mp = 10

	# Create and attach ClassData with specified counter rate
	var class_data: ClassData = ClassData.new()
	class_data.display_name = "TestClass"
	class_data.counter_rate = counter_rate
	stats.class_data = class_data

	return stats


# =============================================================================
# COMBAT CALCULATOR TESTS
# =============================================================================

func _run_combat_calculator_tests() -> void:
	_start_suite("CombatCalculator")

	# Physical Damage Tests
	_test_physical_damage_basic()
	_test_physical_damage_minimum_is_one()
	_test_physical_damage_high_strength()
	_test_physical_damage_null_returns_zero()
	_test_physical_damage_equal_stats()

	# Hit Chance Tests
	_test_hit_chance_base_is_90_with_no_weapon()
	_test_hit_chance_agility_advantage()
	_test_hit_chance_agility_disadvantage()
	_test_hit_chance_minimum_is_10()
	_test_hit_chance_maximum_is_99()
	_test_hit_chance_null_returns_50()

	# Crit Chance Tests
	_test_crit_chance_base_is_5()
	_test_crit_chance_luck_advantage()
	_test_crit_chance_luck_disadvantage()
	_test_crit_chance_maximum_is_50()
	_test_crit_chance_minimum_is_0()

	# Roll Tests
	_test_roll_hit_100_percent()
	_test_roll_hit_0_percent()
	_test_roll_crit_100_percent()
	_test_roll_crit_0_percent()

	# Experience Tests
	_test_experience_same_level()
	_test_experience_higher_enemy()
	_test_experience_lower_enemy()
	_test_experience_minimum_multiplier()

	# Counter Damage Tests
	_test_counter_damage_75_percent()
	_test_counter_damage_cannot_counter()

	# Counterattack Eligibility Tests
	_test_counterattack_melee_vs_melee()
	_test_counterattack_melee_vs_ranged()
	_test_counterattack_ranged_vs_melee()

	# Counter Chance Tests (class-based rates)
	_test_counter_chance_default_rate()
	_test_counter_chance_with_class_data()
	_test_counter_chance_null_stats_returns_zero()
	_test_counter_chance_clamped_at_50()

	# Roll Counter Tests
	_test_roll_counter_100_percent()
	_test_roll_counter_0_percent()
	_test_roll_counter_negative_returns_false()

	# Check Counterattack Integration Tests
	_test_check_counterattack_dead_defender()
	_test_check_counterattack_out_of_range()
	_test_check_counterattack_in_range_can_counter()
	_test_check_counterattack_returns_correct_structure()


# --- Physical Damage Tests ---

func _test_physical_damage_basic() -> void:
	_start_test("physical_damage_basic_calculation")
	var attacker: UnitStats = _create_test_stats(20, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 10, 10, 10, 5)

	if attacker == null or defender == null:
		_fail("Failed to create test stats")
		return

	var all_in_range: bool = true
	for i in range(20):
		var damage: int = CombatCalculator.calculate_physical_damage(attacker, defender)
		if damage < 9 or damage > 11:
			all_in_range = false
			break

	if all_in_range:
		_pass()
	else:
		_fail("Damage not in expected range 9-11")


func _test_physical_damage_minimum_is_one() -> void:
	_start_test("physical_damage_minimum_is_one")
	var attacker: UnitStats = _create_test_stats(5, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 20, 10, 10, 5)

	var all_minimum: bool = true
	for i in range(10):
		var damage: int = CombatCalculator.calculate_physical_damage(attacker, defender)
		if damage != 1:
			all_minimum = false
			break

	if all_minimum:
		_pass()
	else:
		_fail("Minimum damage should be 1")


func _test_physical_damage_high_strength() -> void:
	_start_test("physical_damage_high_strength")
	var attacker: UnitStats = _create_test_stats(50, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 10, 10, 10, 5)

	var all_in_range: bool = true
	for i in range(20):
		var damage: int = CombatCalculator.calculate_physical_damage(attacker, defender)
		if damage < 36 or damage > 44:
			all_in_range = false
			break

	if all_in_range:
		_pass()
	else:
		_fail("High damage not in expected range 36-44")


func _test_physical_damage_null_returns_zero() -> void:
	_start_test("physical_damage_null_returns_zero")
	var defender: UnitStats = _create_test_stats()
	var damage: int = CombatCalculator.calculate_physical_damage(null, defender)
	if _assert_equal(damage, 0):
		_pass()


func _test_physical_damage_equal_stats() -> void:
	_start_test("physical_damage_equal_stats")
	var attacker: UnitStats = _create_test_stats(15, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 15, 10, 10, 5)

	var all_minimum: bool = true
	for i in range(10):
		var damage: int = CombatCalculator.calculate_physical_damage(attacker, defender)
		if damage != 1:
			all_minimum = false
			break

	if all_minimum:
		_pass()
	else:
		_fail("Equal stats should result in minimum damage 1")


# --- Hit Chance Tests ---

func _test_hit_chance_base_is_90_with_no_weapon() -> void:
	_start_test("hit_chance_base_is_90_with_no_weapon")
	var attacker: UnitStats = _create_test_stats(10, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 5, 10, 10, 5)
	var hit_chance: int = CombatCalculator.calculate_hit_chance(attacker, defender)
	# Default weapon hit rate is 90% when no weapon equipped
	if _assert_equal(hit_chance, 90):
		_pass()


func _test_hit_chance_agility_advantage() -> void:
	_start_test("hit_chance_agility_advantage")
	var attacker: UnitStats = _create_test_stats(10, 5, 20, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 5, 10, 10, 5)
	var hit_chance: int = CombatCalculator.calculate_hit_chance(attacker, defender)
	if _assert_equal(hit_chance, 99):  # Clamped at 99
		_pass()


func _test_hit_chance_agility_disadvantage() -> void:
	_start_test("hit_chance_agility_disadvantage")
	var attacker: UnitStats = _create_test_stats(10, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 5, 20, 10, 5)
	var hit_chance: int = CombatCalculator.calculate_hit_chance(attacker, defender)
	# Base 90 - 20 (agility difference * 2) = 70
	if _assert_equal(hit_chance, 70):
		_pass()


func _test_hit_chance_minimum_is_10() -> void:
	_start_test("hit_chance_minimum_is_10")
	var attacker: UnitStats = _create_test_stats(10, 5, 5, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 5, 50, 10, 5)
	var hit_chance: int = CombatCalculator.calculate_hit_chance(attacker, defender)
	if _assert_equal(hit_chance, 10):
		_pass()


func _test_hit_chance_maximum_is_99() -> void:
	_start_test("hit_chance_maximum_is_99")
	var attacker: UnitStats = _create_test_stats(10, 5, 50, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 5, 5, 10, 5)
	var hit_chance: int = CombatCalculator.calculate_hit_chance(attacker, defender)
	if _assert_equal(hit_chance, 99):
		_pass()


func _test_hit_chance_null_returns_50() -> void:
	_start_test("hit_chance_null_returns_50")
	var attacker: UnitStats = _create_test_stats()
	var hit_chance: int = CombatCalculator.calculate_hit_chance(attacker, null)
	if _assert_equal(hit_chance, 50):
		_pass()


# --- Crit Chance Tests ---

func _test_crit_chance_base_is_5() -> void:
	_start_test("crit_chance_base_is_5")
	var attacker: UnitStats = _create_test_stats(10, 5, 10, 10, 10)
	var defender: UnitStats = _create_test_stats(10, 5, 10, 10, 10)
	var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker, defender)
	if _assert_equal(crit_chance, 5):
		_pass()


func _test_crit_chance_luck_advantage() -> void:
	_start_test("crit_chance_luck_advantage")
	var attacker: UnitStats = _create_test_stats(10, 5, 10, 10, 30)
	var defender: UnitStats = _create_test_stats(10, 5, 10, 10, 10)
	var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker, defender)
	if _assert_equal(crit_chance, 25):
		_pass()


func _test_crit_chance_luck_disadvantage() -> void:
	_start_test("crit_chance_luck_disadvantage")
	var attacker: UnitStats = _create_test_stats(10, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 5, 10, 10, 15)
	var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker, defender)
	if _assert_equal(crit_chance, 0):
		_pass()


func _test_crit_chance_maximum_is_50() -> void:
	_start_test("crit_chance_maximum_is_50")
	var attacker: UnitStats = _create_test_stats(10, 5, 10, 10, 100)
	var defender: UnitStats = _create_test_stats(10, 5, 10, 10, 10)
	var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker, defender)
	if _assert_equal(crit_chance, 50):
		_pass()


func _test_crit_chance_minimum_is_0() -> void:
	_start_test("crit_chance_minimum_is_0")
	var attacker: UnitStats = _create_test_stats(10, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 5, 10, 10, 50)
	var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker, defender)
	if _assert_equal(crit_chance, 0):
		_pass()


# --- Roll Tests ---

func _test_roll_hit_100_percent() -> void:
	_start_test("roll_hit_100_percent_always_hits")
	var all_hit: bool = true
	for i in range(20):
		if not CombatCalculator.roll_hit(100):
			all_hit = false
			break

	if all_hit:
		_pass()
	else:
		_fail("100% hit chance should always hit")


func _test_roll_hit_0_percent() -> void:
	_start_test("roll_hit_0_percent_never_hits")
	var any_hit: bool = false
	for i in range(20):
		if CombatCalculator.roll_hit(0):
			any_hit = true
			break

	if not any_hit:
		_pass()
	else:
		_fail("0% hit chance should never hit")


func _test_roll_crit_100_percent() -> void:
	_start_test("roll_crit_100_percent_always_crits")
	var all_crit: bool = true
	for i in range(20):
		if not CombatCalculator.roll_crit(100):
			all_crit = false
			break

	if all_crit:
		_pass()
	else:
		_fail("100% crit chance should always crit")


func _test_roll_crit_0_percent() -> void:
	_start_test("roll_crit_0_percent_never_crits")
	var any_crit: bool = false
	for i in range(20):
		if CombatCalculator.roll_crit(0):
			any_crit = true
			break

	if not any_crit:
		_pass()
	else:
		_fail("0% crit chance should never crit")


# --- Experience Tests ---

func _test_experience_same_level() -> void:
	_start_test("experience_same_level")
	var xp: int = CombatCalculator.calculate_experience_gain(5, 5, 10)
	if _assert_equal(xp, 10):
		_pass()


func _test_experience_higher_enemy() -> void:
	_start_test("experience_higher_enemy")
	var xp: int = CombatCalculator.calculate_experience_gain(5, 7, 10)
	if _assert_equal(xp, 14):
		_pass()


func _test_experience_lower_enemy() -> void:
	_start_test("experience_lower_enemy")
	var xp: int = CombatCalculator.calculate_experience_gain(5, 2, 10)
	if _assert_equal(xp, 7):
		_pass()


func _test_experience_minimum_multiplier() -> void:
	_start_test("experience_minimum_multiplier")
	var xp: int = CombatCalculator.calculate_experience_gain(15, 5, 10)
	if _assert_equal(xp, 5):
		_pass()


# --- Counter Damage Tests ---

func _test_counter_damage_75_percent() -> void:
	_start_test("counter_damage_is_75_percent")
	var defender: UnitStats = _create_test_stats(20, 5, 10, 10, 5)
	var attacker: UnitStats = _create_test_stats(10, 10, 10, 10, 5)

	var all_in_range: bool = true
	for i in range(20):
		var counter_dmg: int = CombatCalculator.calculate_counter_damage(defender, attacker, true)
		if counter_dmg < 6 or counter_dmg > 9:
			all_in_range = false
			break

	if all_in_range:
		_pass()
	else:
		_fail("Counter damage not in expected range 6-9")


func _test_counter_damage_cannot_counter() -> void:
	_start_test("counter_damage_returns_zero_when_cannot_counter")
	var defender: UnitStats = _create_test_stats(20, 5, 10, 10, 5)
	var attacker: UnitStats = _create_test_stats(10, 10, 10, 10, 5)
	var counter_dmg: int = CombatCalculator.calculate_counter_damage(defender, attacker, false)
	if _assert_equal(counter_dmg, 0):
		_pass()


# --- Counterattack Eligibility Tests ---

func _test_counterattack_melee_vs_melee() -> void:
	_start_test("can_counterattack_melee_vs_melee")
	var can_counter: bool = CombatCalculator.can_counterattack(1, 1)
	if _assert_true(can_counter):
		_pass()


func _test_counterattack_melee_vs_ranged() -> void:
	_start_test("cannot_counterattack_melee_vs_ranged")
	var can_counter: bool = CombatCalculator.can_counterattack(1, 3)
	if _assert_false(can_counter):
		_pass()


func _test_counterattack_ranged_vs_melee() -> void:
	_start_test("can_counterattack_ranged_vs_melee")
	var can_counter: bool = CombatCalculator.can_counterattack(3, 1)
	if _assert_true(can_counter):
		_pass()


# --- Counter Chance Tests (class-based rates) ---

func _test_counter_chance_default_rate() -> void:
	_start_test("counter_chance_default_rate_is_12")
	# Stats without class_data should return default 12%
	var stats: UnitStats = _create_test_stats()
	var chance: int = CombatCalculator.calculate_counter_chance(stats)
	if _assert_equal(chance, 12):
		_pass()


func _test_counter_chance_with_class_data() -> void:
	_start_test("counter_chance_uses_class_rate")
	# Test various SF2-style rates: 25% (1/4), 12% (1/8), 6% (1/16), 3% (1/32)
	var stats_25: UnitStats = _create_test_stats_with_class(25)
	var stats_6: UnitStats = _create_test_stats_with_class(6)
	var stats_3: UnitStats = _create_test_stats_with_class(3)

	var chance_25: int = CombatCalculator.calculate_counter_chance(stats_25)
	var chance_6: int = CombatCalculator.calculate_counter_chance(stats_6)
	var chance_3: int = CombatCalculator.calculate_counter_chance(stats_3)

	if _assert_equal(chance_25, 25) and _assert_equal(chance_6, 6) and _assert_equal(chance_3, 3):
		_pass()


func _test_counter_chance_null_stats_returns_zero() -> void:
	_start_test("counter_chance_null_stats_returns_zero")
	var chance: int = CombatCalculator.calculate_counter_chance(null)
	if _assert_equal(chance, 0):
		_pass()


func _test_counter_chance_clamped_at_50() -> void:
	_start_test("counter_chance_clamped_at_50")
	# Even if class has 100% counter rate, should be clamped at 50
	var stats: UnitStats = _create_test_stats_with_class(100)
	var chance: int = CombatCalculator.calculate_counter_chance(stats)
	if _assert_equal(chance, 50):
		_pass()


# --- Roll Counter Tests ---

func _test_roll_counter_100_percent() -> void:
	_start_test("roll_counter_100_percent_always_counters")
	var all_counter: bool = true
	for i in range(20):
		if not CombatCalculator.roll_counter(100):
			all_counter = false
			break

	if all_counter:
		_pass()
	else:
		_fail("100% counter chance should always counter")


func _test_roll_counter_0_percent() -> void:
	_start_test("roll_counter_0_percent_never_counters")
	var any_counter: bool = false
	for i in range(20):
		if CombatCalculator.roll_counter(0):
			any_counter = true
			break

	if not any_counter:
		_pass()
	else:
		_fail("0% counter chance should never counter")


func _test_roll_counter_negative_returns_false() -> void:
	_start_test("roll_counter_negative_returns_false")
	# Negative chance should always return false (early exit)
	var any_counter: bool = false
	for i in range(20):
		if CombatCalculator.roll_counter(-10):
			any_counter = true
			break

	if not any_counter:
		_pass()
	else:
		_fail("Negative counter chance should never counter")


# --- Check Counterattack Integration Tests ---

func _test_check_counterattack_dead_defender() -> void:
	_start_test("check_counterattack_dead_defender_cannot_counter")
	var stats: UnitStats = _create_test_stats_with_class(100)  # 100% rate, but dead

	var result: Dictionary = CombatCalculator.check_counterattack(
		stats,
		1,     # weapon_range
		1,     # attack_distance
		false  # defender_is_alive = false
	)

	if _assert_false(result.can_counter) and _assert_false(result.will_counter) and _assert_equal(result.chance, 0):
		_pass()


func _test_check_counterattack_out_of_range() -> void:
	_start_test("check_counterattack_out_of_range_cannot_counter")
	var stats: UnitStats = _create_test_stats_with_class(100)  # 100% rate, but out of range

	var result: Dictionary = CombatCalculator.check_counterattack(
		stats,
		1,    # weapon_range (melee)
		3,    # attack_distance (3 tiles away - out of reach)
		true  # defender_is_alive
	)

	if _assert_false(result.can_counter) and _assert_false(result.will_counter) and _assert_equal(result.chance, 0):
		_pass()


func _test_check_counterattack_in_range_can_counter() -> void:
	_start_test("check_counterattack_in_range_can_counter")
	var stats: UnitStats = _create_test_stats_with_class(100)  # 100% rate guarantees counter

	var result: Dictionary = CombatCalculator.check_counterattack(
		stats,
		1,    # weapon_range
		1,    # attack_distance (melee vs melee)
		true  # defender_is_alive
	)

	# With 100% counter rate (clamped to 50), we still have can_counter=true
	# But will_counter depends on the roll. Since rate is clamped to 50%,
	# we just check that the structure is correct and chance is 50
	if _assert_true(result.can_counter) and _assert_equal(result.chance, 50):
		_pass()


func _test_check_counterattack_returns_correct_structure() -> void:
	_start_test("check_counterattack_returns_correct_structure")
	var stats: UnitStats = _create_test_stats_with_class(25)

	var result: Dictionary = CombatCalculator.check_counterattack(
		stats,
		2,    # weapon_range
		2,    # attack_distance (ranged match)
		true  # defender_is_alive
	)

	# Verify all expected keys exist
	var has_can_counter: bool = "can_counter" in result
	var has_will_counter: bool = "will_counter" in result
	var has_chance: bool = "chance" in result

	if has_can_counter and has_will_counter and has_chance:
		# Also verify types
		if result.can_counter is bool and result.will_counter is bool and result.chance is int:
			if _assert_equal(result.chance, 25):
				_pass()
		else:
			_fail("Result values have incorrect types")
	else:
		_fail("Result missing expected keys (can_counter, will_counter, chance)")


# =============================================================================
# GRID RESOURCE TESTS
# =============================================================================

func _run_grid_tests() -> void:
	_start_suite("Grid")

	_test_grid_is_within_bounds()
	_test_grid_is_out_of_bounds()
	_test_grid_manhattan_distance()
	_test_grid_get_neighbors_center()
	_test_grid_get_neighbors_corner()
	_test_grid_map_to_local()
	_test_grid_local_to_map()
	_test_grid_cells_in_range()


func _test_grid_is_within_bounds() -> void:
	_start_test("is_within_bounds_true")
	var grid: Grid = Grid.new()
	grid.grid_size = Vector2i(10, 10)

	var in_bounds: bool = grid.is_within_bounds(Vector2i(5, 5))
	if _assert_true(in_bounds):
		_pass()


func _test_grid_is_out_of_bounds() -> void:
	_start_test("is_within_bounds_false_for_out_of_bounds")
	var grid: Grid = Grid.new()
	grid.grid_size = Vector2i(10, 10)

	var out_of_bounds: bool = grid.is_within_bounds(Vector2i(15, 5))
	if _assert_false(out_of_bounds):
		_pass()


func _test_grid_manhattan_distance() -> void:
	_start_test("manhattan_distance")
	var grid: Grid = Grid.new()

	var dist: int = grid.get_manhattan_distance(Vector2i(0, 0), Vector2i(3, 4))
	if _assert_equal(dist, 7):
		_pass()


func _test_grid_get_neighbors_center() -> void:
	_start_test("get_neighbors_center_has_4")
	var grid: Grid = Grid.new()
	grid.grid_size = Vector2i(10, 10)

	var neighbors: Array[Vector2i] = grid.get_neighbors(Vector2i(5, 5))
	if _assert_equal(neighbors.size(), 4):
		_pass()


func _test_grid_get_neighbors_corner() -> void:
	_start_test("get_neighbors_corner_has_2")
	var grid: Grid = Grid.new()
	grid.grid_size = Vector2i(10, 10)

	var neighbors: Array[Vector2i] = grid.get_neighbors(Vector2i(0, 0))
	if _assert_equal(neighbors.size(), 2):
		_pass()


func _test_grid_map_to_local() -> void:
	_start_test("map_to_local_conversion")
	var grid: Grid = Grid.new()
	# Default cell_size is 32, _half_cell_size is 16

	var world_pos: Vector2 = grid.map_to_local(Vector2i(2, 3))
	# Should be (2*32 + 16, 3*32 + 16) = (80, 112) for center of cell
	if _assert_equal(world_pos, Vector2(80, 112)):
		_pass()


func _test_grid_local_to_map() -> void:
	_start_test("local_to_map_conversion")
	var grid: Grid = Grid.new()
	# Default cell_size is 32

	var cell_pos: Vector2i = grid.local_to_map(Vector2(80, 112))
	if _assert_equal(cell_pos, Vector2i(2, 3)):
		_pass()


func _test_grid_cells_in_range() -> void:
	_start_test("get_cells_in_range")
	var grid: Grid = Grid.new()
	grid.grid_size = Vector2i(10, 10)

	# Range 1 from (5, 5) should give 5 cells (center + 4 neighbors)
	var cells: Array[Vector2i] = grid.get_cells_in_range(Vector2i(5, 5), 1)
	if _assert_equal(cells.size(), 5):
		_pass()


# =============================================================================
# UNIT STATS TESTS
# =============================================================================

func _run_unit_stats_tests() -> void:
	_start_suite("UnitStats")

	_test_unit_stats_creation()
	_test_unit_stats_take_damage()
	_test_unit_stats_take_fatal_damage()
	_test_unit_stats_heal()
	_test_unit_stats_heal_over_max()
	_test_unit_stats_spend_mp()
	_test_unit_stats_spend_mp_insufficient()
	_test_unit_stats_status_effect_add()
	_test_unit_stats_status_effect_has()
	_test_unit_stats_status_effect_remove()
	_test_unit_stats_hp_percent()


func _test_unit_stats_creation() -> void:
	_start_test("unit_stats_creation")
	var stats: UnitStats = _create_test_stats(15, 10, 12, 8, 6)

	var all_correct: bool = (
		stats.strength == 15 and
		stats.defense == 10 and
		stats.agility == 12 and
		stats.intelligence == 8 and
		stats.luck == 6
	)

	if all_correct:
		_pass()
	else:
		_fail("Stats not set correctly")


func _test_unit_stats_take_damage() -> void:
	_start_test("take_damage_reduces_hp")
	var stats: UnitStats = _create_test_stats()
	stats.max_hp = 20
	stats.current_hp = 20

	var died: bool = stats.take_damage(5)

	if _assert_equal(stats.current_hp, 15) and _assert_false(died):
		_pass()


func _test_unit_stats_take_fatal_damage() -> void:
	_start_test("take_fatal_damage_returns_true")
	var stats: UnitStats = _create_test_stats()
	stats.max_hp = 20
	stats.current_hp = 10

	var died: bool = stats.take_damage(15)

	if _assert_equal(stats.current_hp, 0) and _assert_true(died):
		_pass()


func _test_unit_stats_heal() -> void:
	_start_test("heal_increases_hp")
	var stats: UnitStats = _create_test_stats()
	stats.max_hp = 20
	stats.current_hp = 10

	stats.heal(5)

	if _assert_equal(stats.current_hp, 15):
		_pass()


func _test_unit_stats_heal_over_max() -> void:
	_start_test("heal_capped_at_max_hp")
	var stats: UnitStats = _create_test_stats()
	stats.max_hp = 20
	stats.current_hp = 18

	stats.heal(10)

	if _assert_equal(stats.current_hp, 20):
		_pass()


func _test_unit_stats_spend_mp() -> void:
	_start_test("spend_mp_reduces_mp")
	var stats: UnitStats = _create_test_stats()
	stats.max_mp = 10
	stats.current_mp = 10

	var success: bool = stats.spend_mp(3)

	if _assert_true(success) and _assert_equal(stats.current_mp, 7):
		_pass()


func _test_unit_stats_spend_mp_insufficient() -> void:
	_start_test("spend_mp_fails_when_insufficient")
	var stats: UnitStats = _create_test_stats()
	stats.max_mp = 10
	stats.current_mp = 5

	var success: bool = stats.spend_mp(10)

	if _assert_false(success) and _assert_equal(stats.current_mp, 5):
		_pass()


func _test_unit_stats_status_effect_add() -> void:
	_start_test("add_status_effect")
	var stats: UnitStats = _create_test_stats()

	stats.add_status_effect("poison", 3, 5)

	if _assert_equal(stats.status_effects.size(), 1):
		_pass()


func _test_unit_stats_status_effect_has() -> void:
	_start_test("has_status_effect")
	var stats: UnitStats = _create_test_stats()
	stats.add_status_effect("poison", 3, 5)

	if _assert_true(stats.has_status_effect("poison")) and _assert_false(stats.has_status_effect("stun")):
		_pass()


func _test_unit_stats_status_effect_remove() -> void:
	_start_test("remove_status_effect")
	var stats: UnitStats = _create_test_stats()
	stats.add_status_effect("poison", 3, 5)
	stats.remove_status_effect("poison")

	if _assert_false(stats.has_status_effect("poison")):
		_pass()


func _test_unit_stats_hp_percent() -> void:
	_start_test("get_hp_percent")
	var stats: UnitStats = _create_test_stats()
	stats.max_hp = 100
	stats.current_hp = 75

	var percent: float = stats.get_hp_percent()

	if _assert_equal(percent, 0.75):
		_pass()


# =============================================================================
# EXPERIENCE CONFIG TESTS
# =============================================================================

func _run_experience_config_tests() -> void:
	_start_suite("ExperienceConfig")

	# Level difference XP tests
	_test_xp_table_very_low_level_returns_zero()
	_test_xp_table_7_below_returns_zero()
	_test_xp_table_6_below_returns_10()
	_test_xp_table_5_below_returns_20()
	_test_xp_table_4_below_returns_30()
	_test_xp_table_3_below_returns_40()
	_test_xp_table_2_below_returns_50()
	_test_xp_table_same_level_returns_50()
	_test_xp_table_above_capped_at_50()

	# Anti-spam multiplier tests
	_test_antispam_initial_returns_1()
	_test_antispam_below_threshold_returns_1()
	_test_antispam_medium_threshold_returns_06()
	_test_antispam_heavy_threshold_returns_03()
	_test_antispam_disabled_returns_1()


# --- Level Difference XP Table Tests ---

func _test_xp_table_very_low_level_returns_zero() -> void:
	_start_test("xp_table_very_low_level_returns_zero")
	var config: ExperienceConfig = ExperienceConfig.new()
	var xp: int = config.get_base_xp_from_level_diff(-20)
	if _assert_equal(xp, 0):
		_pass()


func _test_xp_table_7_below_returns_zero() -> void:
	_start_test("xp_table_7_below_returns_zero")
	var config: ExperienceConfig = ExperienceConfig.new()
	var xp: int = config.get_base_xp_from_level_diff(-7)
	if _assert_equal(xp, 0):
		_pass()


func _test_xp_table_6_below_returns_10() -> void:
	_start_test("xp_table_6_below_returns_10")
	var config: ExperienceConfig = ExperienceConfig.new()
	var xp: int = config.get_base_xp_from_level_diff(-6)
	if _assert_equal(xp, 10):
		_pass()


func _test_xp_table_5_below_returns_20() -> void:
	_start_test("xp_table_5_below_returns_20")
	var config: ExperienceConfig = ExperienceConfig.new()
	var xp: int = config.get_base_xp_from_level_diff(-5)
	if _assert_equal(xp, 20):
		_pass()


func _test_xp_table_4_below_returns_30() -> void:
	_start_test("xp_table_4_below_returns_30")
	var config: ExperienceConfig = ExperienceConfig.new()
	var xp: int = config.get_base_xp_from_level_diff(-4)
	if _assert_equal(xp, 30):
		_pass()


func _test_xp_table_3_below_returns_40() -> void:
	_start_test("xp_table_3_below_returns_40")
	var config: ExperienceConfig = ExperienceConfig.new()
	var xp: int = config.get_base_xp_from_level_diff(-3)
	if _assert_equal(xp, 40):
		_pass()


func _test_xp_table_2_below_returns_50() -> void:
	_start_test("xp_table_2_below_returns_50")
	var config: ExperienceConfig = ExperienceConfig.new()
	var xp: int = config.get_base_xp_from_level_diff(-2)
	if _assert_equal(xp, 50):
		_pass()


func _test_xp_table_same_level_returns_50() -> void:
	_start_test("xp_table_same_level_returns_50")
	var config: ExperienceConfig = ExperienceConfig.new()
	var xp: int = config.get_base_xp_from_level_diff(0)
	if _assert_equal(xp, 50):
		_pass()


func _test_xp_table_above_capped_at_50() -> void:
	_start_test("xp_table_above_level_capped_at_50")
	var config: ExperienceConfig = ExperienceConfig.new()
	# Even 10 levels above still caps at 50
	var xp: int = config.get_base_xp_from_level_diff(10)
	if _assert_equal(xp, 50):
		_pass()


# --- Anti-Spam Multiplier Tests ---

func _test_antispam_initial_returns_1() -> void:
	_start_test("antispam_initial_usage_returns_1")
	var config: ExperienceConfig = ExperienceConfig.new()
	var mult: float = config.get_anti_spam_multiplier(0)
	if _assert_equal(mult, 1.0):
		_pass()


func _test_antispam_below_threshold_returns_1() -> void:
	_start_test("antispam_below_threshold_returns_1")
	var config: ExperienceConfig = ExperienceConfig.new()
	# Default spam_threshold_medium is 5, so 4 uses should still be 1.0
	var mult: float = config.get_anti_spam_multiplier(4)
	if _assert_equal(mult, 1.0):
		_pass()


func _test_antispam_medium_threshold_returns_06() -> void:
	_start_test("antispam_medium_threshold_returns_0.6")
	var config: ExperienceConfig = ExperienceConfig.new()
	# Default spam_threshold_medium is 5
	var mult: float = config.get_anti_spam_multiplier(5)
	if _assert_equal(mult, 0.6):
		_pass()


func _test_antispam_heavy_threshold_returns_03() -> void:
	_start_test("antispam_heavy_threshold_returns_0.3")
	var config: ExperienceConfig = ExperienceConfig.new()
	# Default spam_threshold_heavy is 8
	var mult: float = config.get_anti_spam_multiplier(8)
	if _assert_equal(mult, 0.3):
		_pass()


func _test_antispam_disabled_returns_1() -> void:
	_start_test("antispam_disabled_always_returns_1")
	var config: ExperienceConfig = ExperienceConfig.new()
	config.anti_spam_enabled = false
	# Even at heavy usage, should return 1.0 when disabled
	var mult: float = config.get_anti_spam_multiplier(20)
	if _assert_equal(mult, 1.0):
		_pass()


# =============================================================================
# ITEM MENU INTEGRATION TESTS
# =============================================================================

func _run_item_menu_integration_tests() -> void:
	_start_suite("ItemMenuIntegration")

	_test_items_discovered()
	_test_starting_inventory_copy()
	_test_party_manager_save_data()


func _test_items_discovered() -> void:
	_start_test("items_discovered_by_mod_loader")

	# Test that ModLoader.registry can discover and return items
	# Uses mock item data instead of depending on specific mod content
	var ItemDataScript: GDScript = preload("res://core/resources/item_data.gd")
	
	# Create a test item
	var test_item: ItemData = ItemDataScript.new()
	test_item.item_id = "_test_healing_herb"
	test_item.item_name = "Test Healing Herb"
	test_item.usable_in_battle = true
	test_item.usable_in_field = true
	
	# Register it
	ModLoader.registry.register_item(test_item, "_test_mod")
	
	# Check if it can be retrieved
	var retrieved: ItemData = ModLoader.registry.get_item("_test_healing_herb")
	if not _assert_not_null(retrieved, "registered item should be retrievable"):
		return
	
	# Check properties were preserved
	if not _assert_equal(retrieved.item_name, "Test Healing Herb", "item_name should match"):
		return
	
	if not _assert_true(retrieved.usable_in_battle, "usable_in_battle should be true"):
		return
	
	# Clean up
	ModLoader.registry.unregister_item("_test_healing_herb")
	
	_pass()


func _test_starting_inventory_copy() -> void:
	_start_test("starting_inventory_copied_to_save_data")

	# Test that CharacterSaveData.populate_from_character_data() copies starting_inventory
	# Uses mock data instead of depending on specific mod content
	var CharacterDataScript: GDScript = preload("res://core/resources/character_data.gd")
	
	# Create a test character with starting inventory (item IDs as strings)
	var test_char: CharacterData = CharacterDataScript.new()
	test_char.character_uid = "_test_hero_uid"
	test_char.character_name = "Test Hero"
	test_char.starting_inventory = ["_test_sword", "_test_potion"]
	
	# Create CharacterSaveData and populate
	var save_data: CharacterSaveData = CharacterSaveData.new()
	save_data.populate_from_character_data(test_char)

	# Check inventory was copied
	if not _assert_equal(save_data.inventory.size(), 2, "inventory size should be 2"):
		return
	
	if _assert_equal(save_data.inventory[0], "_test_sword", "inventory should contain test item ID"):
		_pass()


func _test_party_manager_save_data() -> void:
	_start_test("party_manager_get_member_save_data")

	# Test PartyManager.get_member_save_data() functionality
	# Uses mock data instead of depending on specific mod content
	var CharacterDataScript: GDScript = preload("res://core/resources/character_data.gd")
	
	# Create a test character with starting inventory (item IDs as strings)
	var test_char: CharacterData = CharacterDataScript.new()
	test_char.character_uid = "_test_party_hero"
	test_char.character_name = "Test Party Hero"
	test_char.starting_inventory = ["_test_party_item"]

	# Clear party and add test character
	PartyManager.clear_party()
	PartyManager.add_member(test_char)

	# Check party size
	if not _assert_equal(PartyManager.get_party_size(), 1, "party size"):
		PartyManager.clear_party()
		return

	# Check has_method for get_member_save_data
	if not _assert_true(PartyManager.has_method("get_member_save_data"), "has get_member_save_data"):
		PartyManager.clear_party()
		return

	# Get save data
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(test_char.character_uid)
	if not _assert_not_null(save_data, "get_member_save_data should return data"):
		PartyManager.clear_party()
		return

	# Check inventory was populated from starting_inventory
	if not _assert_equal(save_data.inventory.size(), 1, "save data should have 1 inventory item"):
		PartyManager.clear_party()
		return

	_pass()

	# Clean up
	PartyManager.clear_party()
