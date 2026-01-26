## RandomManager Unit Tests
##
## Tests the RandomManager seeded RNG functionality:
## - Seed management (set, reset, randomize)
## - Deterministic sequences from seeds
## - Combat convenience methods (roll_hit, roll_crit, etc.)
## - Export/import for saves
## - Separate RNG streams don't affect each other
##
## Note: This is a UNIT test - creates a fresh RandomManager instance,
## does not use the autoload singleton.
class_name TestRandomManager
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

const RandomManagerScript = preload("res://core/systems/random_manager.gd")

var _rng: Node


func before_test() -> void:
	_rng = RandomManagerScript.new()
	add_child(_rng)


func after_test() -> void:
	if _rng and is_instance_valid(_rng):
		_rng.queue_free()
	_rng = null


# =============================================================================
# SEED MANAGEMENT TESTS
# =============================================================================

func test_set_combat_seed_makes_deterministic() -> void:
	_rng.set_combat_seed(12345)

	assert_bool(_rng._seeds_are_deterministic).is_true()


func test_set_ai_seed_makes_deterministic() -> void:
	_rng.set_ai_seed(54321)

	assert_bool(_rng._seeds_are_deterministic).is_true()


func test_set_world_seed_makes_deterministic() -> void:
	_rng.set_world_seed(99999)

	assert_bool(_rng._seeds_are_deterministic).is_true()


func test_set_all_seeds_configures_all_rngs() -> void:
	_rng.set_all_seeds(111, 222, 333)

	assert_int(_rng._combat_seed).is_equal(111)
	assert_int(_rng._ai_seed).is_equal(222)
	assert_int(_rng._world_seed).is_equal(333)
	assert_bool(_rng._seeds_are_deterministic).is_true()


func test_randomize_all_seeds_clears_deterministic() -> void:
	_rng.set_all_seeds(111, 222, 333)

	_rng.randomize_all_seeds()

	assert_bool(_rng._seeds_are_deterministic).is_false()


func test_reset_all_seeds_restores_initial_sequence() -> void:
	_rng.set_combat_seed(42)
	var first_value: int = _rng.combat_rng.randi()
	_rng.combat_rng.randi()
	_rng.combat_rng.randi()

	_rng.reset_all_seeds()
	var after_reset: int = _rng.combat_rng.randi()

	assert_int(after_reset).is_equal(first_value)


# =============================================================================
# DETERMINISTIC SEQUENCE TESTS
# =============================================================================

func test_same_seed_produces_same_sequence() -> void:
	_rng.set_combat_seed(42)
	var sequence1: Array[int] = []
	for _i: int in range(5):
		sequence1.append(_rng.combat_rng.randi_range(0, 100))

	_rng.set_combat_seed(42)
	var sequence2: Array[int] = []
	for _i: int in range(5):
		sequence2.append(_rng.combat_rng.randi_range(0, 100))

	for i: int in range(5):
		assert_int(sequence2[i]).is_equal(sequence1[i])


func test_different_seeds_produce_different_sequences() -> void:
	_rng.set_combat_seed(42)
	var value1: int = _rng.combat_rng.randi()

	_rng.set_combat_seed(43)
	var value2: int = _rng.combat_rng.randi()

	assert_int(value1).is_not_equal(value2)


func test_separate_rng_streams_are_independent() -> void:
	# Set all to same seed but advance combat_rng
	_rng.set_all_seeds(100, 100, 100)
	_rng.combat_rng.randi()
	_rng.combat_rng.randi()
	_rng.combat_rng.randi()

	# AI and world should still be at start of sequence
	var ai_val: int = _rng.ai_rng.randi()
	var world_val: int = _rng.world_rng.randi()

	# They should both produce the same first value (same seed)
	assert_int(ai_val).is_equal(world_val)


# =============================================================================
# COMBAT CONVENIENCE METHOD TESTS
# =============================================================================

func test_roll_hit_returns_true_for_100_percent() -> void:
	_rng.set_combat_seed(999)

	var result: bool = _rng.roll_hit(100)

	assert_bool(result).is_true()


func test_roll_hit_returns_false_for_0_percent() -> void:
	_rng.set_combat_seed(999)

	var result: bool = _rng.roll_hit(0)

	assert_bool(result).is_false()


func test_roll_hit_is_deterministic() -> void:
	_rng.set_combat_seed(42)
	var result1: bool = _rng.roll_hit(50)

	_rng.set_combat_seed(42)
	var result2: bool = _rng.roll_hit(50)

	assert_bool(result1).is_equal(result2)


func test_roll_crit_returns_true_for_100_percent() -> void:
	_rng.set_combat_seed(999)

	var result: bool = _rng.roll_crit(100)

	assert_bool(result).is_true()


func test_roll_crit_returns_false_for_0_percent() -> void:
	_rng.set_combat_seed(999)

	var result: bool = _rng.roll_crit(0)

	assert_bool(result).is_false()


func test_roll_counter_is_deterministic() -> void:
	_rng.set_combat_seed(123)
	var result1: bool = _rng.roll_counter(30)

	_rng.set_combat_seed(123)
	var result2: bool = _rng.roll_counter(30)

	assert_bool(result1).is_equal(result2)


func test_get_damage_variance_in_range() -> void:
	_rng.set_combat_seed(42)

	for _i: int in range(20):
		var variance: float = _rng.get_damage_variance()
		assert_float(variance).is_greater_equal(0.9)
		assert_float(variance).is_less_equal(1.1)


func test_get_damage_variance_custom_range() -> void:
	_rng.set_combat_seed(42)

	for _i: int in range(20):
		var variance: float = _rng.get_damage_variance(0.5, 1.5)
		assert_float(variance).is_greater_equal(0.5)
		assert_float(variance).is_less_equal(1.5)


func test_roll_dice_single_d6_in_range() -> void:
	_rng.set_combat_seed(42)

	for _i: int in range(20):
		var result: int = _rng.roll_dice(6)
		assert_int(result).is_greater_equal(1)
		assert_int(result).is_less_equal(6)


func test_roll_dice_multiple_d6_in_range() -> void:
	_rng.set_combat_seed(42)

	for _i: int in range(20):
		var result: int = _rng.roll_dice(6, 3)
		# 3d6 ranges from 3 to 18
		assert_int(result).is_greater_equal(3)
		assert_int(result).is_less_equal(18)


func test_roll_dice_is_deterministic() -> void:
	_rng.set_combat_seed(42)
	var result1: int = _rng.roll_dice(20, 2)

	_rng.set_combat_seed(42)
	var result2: int = _rng.roll_dice(20, 2)

	assert_int(result1).is_equal(result2)


# =============================================================================
# EXPORT/IMPORT TESTS
# =============================================================================

func test_export_seeds_includes_all_seeds() -> void:
	_rng.set_all_seeds(111, 222, 333)

	var exported: Dictionary = _rng.export_seeds()

	assert_int(exported.combat_seed).is_equal(111)
	assert_int(exported.ai_seed).is_equal(222)
	assert_int(exported.world_seed).is_equal(333)
	assert_bool(exported.deterministic).is_true()


func test_export_seeds_includes_rng_state() -> void:
	_rng.set_combat_seed(42)
	_rng.combat_rng.randi()
	_rng.combat_rng.randi()

	var exported: Dictionary = _rng.export_seeds()

	assert_bool("combat_state" in exported).is_true()
	assert_bool("ai_state" in exported).is_true()
	assert_bool("world_state" in exported).is_true()


func test_import_seeds_restores_seeds() -> void:
	var data: Dictionary = {
		"combat_seed": 555,
		"ai_seed": 666,
		"world_seed": 777,
		"deterministic": true
	}

	_rng.import_seeds(data)

	assert_int(_rng._combat_seed).is_equal(555)
	assert_int(_rng._ai_seed).is_equal(666)
	assert_int(_rng._world_seed).is_equal(777)


func test_import_seeds_restores_rng_state() -> void:
	# Generate some values and export state
	_rng.set_combat_seed(42)
	_rng.combat_rng.randi()
	_rng.combat_rng.randi()
	var next_expected: int = _rng.combat_rng.randi()
	_rng.combat_rng.seed = 42  # Reset
	_rng.combat_rng.randi()
	_rng.combat_rng.randi()
	var state_data: Dictionary = _rng.export_seeds()

	# Create fresh RNG and import
	var rng2: Node = RandomManagerScript.new()
	add_child(rng2)
	rng2.import_seeds(state_data)
	var actual: int = rng2.combat_rng.randi()
	rng2.queue_free()

	assert_int(actual).is_equal(next_expected)


func test_import_seeds_handles_missing_state() -> void:
	# Import with only seeds, no state
	var data: Dictionary = {
		"combat_seed": 123,
		"ai_seed": 456,
		"world_seed": 789
	}

	_rng.import_seeds(data)

	# Should not crash, should use seed instead
	assert_int(_rng._combat_seed).is_equal(123)


func test_import_seeds_handles_missing_deterministic_flag() -> void:
	var data: Dictionary = {
		"combat_seed": 123,
		"ai_seed": 456,
		"world_seed": 789
		# deterministic missing
	}

	_rng.import_seeds(data)

	assert_bool(_rng._seeds_are_deterministic).is_false()


# =============================================================================
# DEBUG STRING TEST
# =============================================================================

func test_get_debug_string_contains_seeds() -> void:
	_rng.set_all_seeds(100, 200, 300)

	var debug: String = _rng.get_debug_string()

	assert_str(debug).contains("combat=100")
	assert_str(debug).contains("ai=200")
	assert_str(debug).contains("world=300")
	assert_str(debug).contains("deterministic=true")
