## Headless Test Runner for Sparkling Farce
##
## Runs unit tests without requiring the full gdUnit4 plugin infrastructure.
## Uses a simple assertion system compatible with CI/headless execution.
##
## Usage: godot --headless -s res://tests/test_runner.gd
extends SceneTree


## Test results tracking
var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []
var _current_test_suite: String = ""
var _current_test: String = ""


func _init() -> void:
	print("\n" + "=".repeat(60))
	print("SPARKLING FARCE - UNIT TEST RUNNER")
	print("=".repeat(60) + "\n")

	# Run all test suites
	_run_combat_calculator_tests()

	# Print summary
	_print_summary()

	# Exit with appropriate code
	quit(0 if _failed == 0 else 1)


func _print_summary() -> void:
	print("\n" + "=".repeat(60))
	print("TEST SUMMARY")
	print("=".repeat(60))
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)

	if _errors.size() > 0:
		print("\nFailed Tests:")
		for error in _errors:
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
	_test_hit_chance_base_is_80()
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


# --- Physical Damage Tests ---

func _test_physical_damage_basic() -> void:
	_start_test("physical_damage_basic_calculation")
	var attacker: UnitStats = _create_test_stats(20, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 10, 10, 10, 5)

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

func _test_hit_chance_base_is_80() -> void:
	_start_test("hit_chance_base_is_80")
	var attacker: UnitStats = _create_test_stats(10, 5, 10, 10, 5)
	var defender: UnitStats = _create_test_stats(10, 5, 10, 10, 5)
	var hit_chance: int = CombatCalculator.calculate_hit_chance(attacker, defender)
	if _assert_equal(hit_chance, 80):
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
	if _assert_equal(hit_chance, 60):
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
