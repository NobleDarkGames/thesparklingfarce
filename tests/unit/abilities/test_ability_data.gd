## Unit Tests for AbilityData
##
## Tests validation, targeting logic, range checking, and cost formatting.
## Pure resource tests - no scene dependencies.
class_name TestAbilityData
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

## Create a valid AbilityData with defaults
func _create_test_ability(
	name: String = "Test Ability",
	ability_type: AbilityData.AbilityType = AbilityData.AbilityType.ATTACK,
	target_type: AbilityData.TargetType = AbilityData.TargetType.SINGLE_ENEMY
) -> AbilityData:
	var ability: AbilityData = AbilityData.new()
	ability.ability_name = name
	ability.ability_id = name.to_lower().replace(" ", "_")
	ability.ability_type = ability_type
	ability.target_type = target_type
	ability.min_range = 1
	ability.max_range = 1
	return ability


## Create an ability with specific range
func _create_ranged_ability(min_r: int, max_r: int) -> AbilityData:
	var ability: AbilityData = _create_test_ability()
	ability.min_range = min_r
	ability.max_range = max_r
	return ability


## Create an ability with specific costs
func _create_costed_ability(mp: int, hp: int) -> AbilityData:
	var ability: AbilityData = _create_test_ability()
	ability.mp_cost = mp
	ability.hp_cost = hp
	return ability


# =============================================================================
# VALIDATION TESTS
# =============================================================================

func test_validate_requires_name() -> void:
	var ability: AbilityData = AbilityData.new()
	ability.ability_name = ""
	ability.min_range = 1
	ability.max_range = 1

	var result: bool = ability.validate()
	assert_bool(result).is_false()


func test_validate_passes_with_name() -> void:
	var ability: AbilityData = _create_test_ability("Blaze")

	var result: bool = ability.validate()
	assert_bool(result).is_true()


func test_validate_range_min_less_than_max() -> void:
	var ability: AbilityData = _create_test_ability()
	ability.min_range = 5
	ability.max_range = 2  # Invalid: max < min

	var result: bool = ability.validate()
	assert_bool(result).is_false()


func test_validate_range_equal_is_valid() -> void:
	var ability: AbilityData = _create_test_ability()
	ability.min_range = 3
	ability.max_range = 3  # Valid: equal range

	var result: bool = ability.validate()
	assert_bool(result).is_true()


func test_validate_costs_non_negative_mp() -> void:
	var ability: AbilityData = _create_test_ability()
	ability.mp_cost = -5  # Invalid

	var result: bool = ability.validate()
	assert_bool(result).is_false()


func test_validate_costs_non_negative_hp() -> void:
	var ability: AbilityData = _create_test_ability()
	ability.hp_cost = -10  # Invalid

	var result: bool = ability.validate()
	assert_bool(result).is_false()


func test_validate_zero_costs_are_valid() -> void:
	var ability: AbilityData = _create_test_ability()
	ability.mp_cost = 0
	ability.hp_cost = 0

	var result: bool = ability.validate()
	assert_bool(result).is_true()


func test_validate_positive_costs_are_valid() -> void:
	var ability: AbilityData = _create_test_ability()
	ability.mp_cost = 10
	ability.hp_cost = 5

	var result: bool = ability.validate()
	assert_bool(result).is_true()


# =============================================================================
# TARGET TYPE LOGIC - ENEMIES
# =============================================================================

func test_can_target_enemies_single_enemy() -> void:
	var ability: AbilityData = _create_test_ability("Attack", AbilityData.AbilityType.ATTACK, AbilityData.TargetType.SINGLE_ENEMY)

	assert_bool(ability.can_target_enemies()).is_true()


func test_can_target_enemies_all_enemies() -> void:
	var ability: AbilityData = _create_test_ability("Blaze", AbilityData.AbilityType.ATTACK, AbilityData.TargetType.ALL_ENEMIES)

	assert_bool(ability.can_target_enemies()).is_true()


func test_can_target_enemies_area() -> void:
	var ability: AbilityData = _create_test_ability("Freeze", AbilityData.AbilityType.ATTACK, AbilityData.TargetType.AREA)

	assert_bool(ability.can_target_enemies()).is_true()


func test_cannot_target_enemies_single_ally() -> void:
	var ability: AbilityData = _create_test_ability("Heal", AbilityData.AbilityType.HEAL, AbilityData.TargetType.SINGLE_ALLY)

	assert_bool(ability.can_target_enemies()).is_false()


func test_cannot_target_enemies_all_allies() -> void:
	var ability: AbilityData = _create_test_ability("Aura", AbilityData.AbilityType.HEAL, AbilityData.TargetType.ALL_ALLIES)

	assert_bool(ability.can_target_enemies()).is_false()


func test_cannot_target_enemies_self() -> void:
	var ability: AbilityData = _create_test_ability("Boost", AbilityData.AbilityType.SUPPORT, AbilityData.TargetType.SELF)

	assert_bool(ability.can_target_enemies()).is_false()


# =============================================================================
# TARGET TYPE LOGIC - ALLIES
# =============================================================================

func test_can_target_allies_single_ally() -> void:
	var ability: AbilityData = _create_test_ability("Heal", AbilityData.AbilityType.HEAL, AbilityData.TargetType.SINGLE_ALLY)

	assert_bool(ability.can_target_allies()).is_true()


func test_can_target_allies_all_allies() -> void:
	var ability: AbilityData = _create_test_ability("Aura", AbilityData.AbilityType.HEAL, AbilityData.TargetType.ALL_ALLIES)

	assert_bool(ability.can_target_allies()).is_true()


func test_can_target_allies_self() -> void:
	var ability: AbilityData = _create_test_ability("Boost", AbilityData.AbilityType.SUPPORT, AbilityData.TargetType.SELF)

	assert_bool(ability.can_target_allies()).is_true()


func test_can_target_allies_area() -> void:
	# AREA can target both enemies and allies (zone effects)
	var ability: AbilityData = _create_test_ability("Nova", AbilityData.AbilityType.ATTACK, AbilityData.TargetType.AREA)

	assert_bool(ability.can_target_allies()).is_true()


func test_cannot_target_allies_single_enemy() -> void:
	var ability: AbilityData = _create_test_ability("Attack", AbilityData.AbilityType.ATTACK, AbilityData.TargetType.SINGLE_ENEMY)

	assert_bool(ability.can_target_allies()).is_false()


func test_cannot_target_allies_all_enemies() -> void:
	var ability: AbilityData = _create_test_ability("Blaze", AbilityData.AbilityType.ATTACK, AbilityData.TargetType.ALL_ENEMIES)

	assert_bool(ability.can_target_allies()).is_false()


# =============================================================================
# RANGE VALIDATION
# =============================================================================

func test_is_in_range_within_bounds() -> void:
	var ability: AbilityData = _create_ranged_ability(1, 3)

	assert_bool(ability.is_in_range(2)).is_true()


func test_is_in_range_exact_min() -> void:
	var ability: AbilityData = _create_ranged_ability(1, 3)

	assert_bool(ability.is_in_range(1)).is_true()


func test_is_in_range_exact_max() -> void:
	var ability: AbilityData = _create_ranged_ability(1, 3)

	assert_bool(ability.is_in_range(3)).is_true()


func test_is_in_range_below_min() -> void:
	var ability: AbilityData = _create_ranged_ability(2, 4)

	assert_bool(ability.is_in_range(1)).is_false()


func test_is_in_range_above_max() -> void:
	var ability: AbilityData = _create_ranged_ability(1, 3)

	assert_bool(ability.is_in_range(4)).is_false()


func test_is_in_range_zero_for_self() -> void:
	# Self-targeting abilities have min_range 0
	var ability: AbilityData = _create_ranged_ability(0, 0)

	assert_bool(ability.is_in_range(0)).is_true()


func test_is_in_range_negative_returns_false() -> void:
	var ability: AbilityData = _create_ranged_ability(1, 3)

	assert_bool(ability.is_in_range(-1)).is_false()


func test_is_in_range_large_distance() -> void:
	var ability: AbilityData = _create_ranged_ability(1, 5)

	assert_bool(ability.is_in_range(10)).is_false()


# =============================================================================
# STATUS EFFECTS
# =============================================================================

func test_has_status_effects_with_single_effect() -> void:
	var ability: AbilityData = _create_test_ability()
	ability.status_effects = ["poison"]

	assert_bool(ability.has_status_effects()).is_true()


func test_has_status_effects_with_multiple_effects() -> void:
	var ability: AbilityData = _create_test_ability()
	ability.status_effects = ["poison", "slow", "weakness"]

	assert_bool(ability.has_status_effects()).is_true()


func test_has_status_effects_empty_array() -> void:
	var ability: AbilityData = _create_test_ability()
	ability.status_effects = []

	assert_bool(ability.has_status_effects()).is_false()


func test_has_status_effects_default_is_empty() -> void:
	var ability: AbilityData = AbilityData.new()

	assert_bool(ability.has_status_effects()).is_false()


# =============================================================================
# COST FORMATTING
# =============================================================================

func test_get_cost_string_mp_only() -> void:
	var ability: AbilityData = _create_costed_ability(10, 0)

	var cost_str: String = ability.get_cost_string()
	assert_str(cost_str).is_equal("10 MP")


func test_get_cost_string_hp_only() -> void:
	var ability: AbilityData = _create_costed_ability(0, 5)

	var cost_str: String = ability.get_cost_string()
	assert_str(cost_str).is_equal("5 HP")


func test_get_cost_string_both_costs() -> void:
	var ability: AbilityData = _create_costed_ability(8, 4)

	var cost_str: String = ability.get_cost_string()
	assert_str(cost_str).is_equal("8 MP / 4 HP")


func test_get_cost_string_no_cost() -> void:
	var ability: AbilityData = _create_costed_ability(0, 0)

	var cost_str: String = ability.get_cost_string()
	assert_str(cost_str).is_equal("No cost")


func test_get_cost_string_high_values() -> void:
	var ability: AbilityData = _create_costed_ability(99, 50)

	var cost_str: String = ability.get_cost_string()
	assert_str(cost_str).is_equal("99 MP / 50 HP")


# =============================================================================
# ABILITY TYPE TESTS
# =============================================================================

func test_ability_type_default_is_attack() -> void:
	var ability: AbilityData = AbilityData.new()

	assert_int(ability.ability_type).is_equal(AbilityData.AbilityType.ATTACK)


func test_ability_type_heal() -> void:
	var ability: AbilityData = _create_test_ability("Heal", AbilityData.AbilityType.HEAL)

	assert_int(ability.ability_type).is_equal(AbilityData.AbilityType.HEAL)


func test_ability_type_support() -> void:
	var ability: AbilityData = _create_test_ability("Boost", AbilityData.AbilityType.SUPPORT)

	assert_int(ability.ability_type).is_equal(AbilityData.AbilityType.SUPPORT)


func test_ability_type_custom_with_id() -> void:
	var ability: AbilityData = _create_test_ability("Warp", AbilityData.AbilityType.CUSTOM)
	ability.custom_ability_type = "teleport"

	assert_int(ability.ability_type).is_equal(AbilityData.AbilityType.CUSTOM)
	assert_str(ability.custom_ability_type).is_equal("teleport")


# =============================================================================
# AREA OF EFFECT TESTS
# =============================================================================

func test_area_of_effect_default_is_zero() -> void:
	var ability: AbilityData = AbilityData.new()

	assert_int(ability.area_of_effect).is_equal(0)


func test_area_of_effect_can_be_set() -> void:
	var ability: AbilityData = _create_test_ability()
	ability.area_of_effect = 2

	assert_int(ability.area_of_effect).is_equal(2)


# =============================================================================
# ACCURACY TESTS
# =============================================================================

func test_accuracy_default_is_100() -> void:
	var ability: AbilityData = AbilityData.new()

	assert_int(ability.accuracy).is_equal(100)


func test_accuracy_can_be_reduced() -> void:
	var ability: AbilityData = _create_test_ability()
	ability.accuracy = 75

	assert_int(ability.accuracy).is_equal(75)


# =============================================================================
# EFFECT DURATION AND CHANCE
# =============================================================================

func test_effect_duration_default_is_three() -> void:
	var ability: AbilityData = AbilityData.new()

	assert_int(ability.effect_duration).is_equal(3)


func test_effect_chance_default_is_100() -> void:
	var ability: AbilityData = AbilityData.new()

	assert_int(ability.effect_chance).is_equal(100)


func test_effect_chance_can_be_reduced() -> void:
	var ability: AbilityData = _create_test_ability()
	ability.effect_chance = 50

	assert_int(ability.effect_chance).is_equal(50)
