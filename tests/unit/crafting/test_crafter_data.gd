## Unit Tests for CrafterData Resource
##
## Tests the crafter NPC data used in the crafting system.
class_name TestCrafterData
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

func _create_crafter(
	crafter_name: String = "Village Smith",
	crafter_type: String = "blacksmith",
	skill: int = 1
) -> CrafterData:
	var crafter: CrafterData = CrafterData.new()
	crafter.crafter_name = crafter_name
	crafter.crafter_type = crafter_type
	crafter.skill_level = skill
	return crafter


## Flag checker that always returns false
func _no_flags(_flag: String) -> bool:
	return false


## Flag checker that always returns true
func _all_flags(_flag: String) -> bool:
	return true


## Create a flag checker from a list of set flags
func _flag_checker_from_list(flags: Array[String]) -> Callable:
	return func(flag: String) -> bool:
		return flag in flags


# =============================================================================
# BASIC PROPERTY TESTS
# =============================================================================

func test_default_values() -> void:
	var crafter: CrafterData = CrafterData.new()

	assert_str(crafter.crafter_name).is_equal("")
	assert_str(crafter.crafter_type).is_equal("")
	assert_int(crafter.skill_level).is_equal(1)
	assert_array(crafter.specializations).is_empty()
	assert_float(crafter.service_fee_modifier).is_equal(1.0)


func test_properties_set_correctly() -> void:
	var crafter: CrafterData = _create_crafter("Master Enchanter", "enchanter", 5)
	crafter.specializations = ["fire", "holy"] as Array[String]
	crafter.location_map_id = "magic_tower"
	crafter.location_grid_position = Vector2i(10, 5)

	assert_str(crafter.crafter_name).is_equal("Master Enchanter")
	assert_str(crafter.crafter_type).is_equal("enchanter")
	assert_int(crafter.skill_level).is_equal(5)
	assert_array(crafter.specializations).contains(["fire", "holy"])
	assert_str(crafter.location_map_id).is_equal("magic_tower")


# =============================================================================
# CAN CRAFT RECIPE TESTS
# =============================================================================

func test_can_craft_recipe_matching_type_and_skill() -> void:
	var crafter: CrafterData = _create_crafter("Smith", "blacksmith", 3)

	assert_bool(crafter.can_craft_recipe("blacksmith", 1)).is_true()
	assert_bool(crafter.can_craft_recipe("blacksmith", 2)).is_true()
	assert_bool(crafter.can_craft_recipe("blacksmith", 3)).is_true()


func test_can_craft_recipe_insufficient_skill() -> void:
	var crafter: CrafterData = _create_crafter("Apprentice", "blacksmith", 1)

	assert_bool(crafter.can_craft_recipe("blacksmith", 2)).is_false()
	assert_bool(crafter.can_craft_recipe("blacksmith", 5)).is_false()


func test_can_craft_recipe_wrong_type() -> void:
	var crafter: CrafterData = _create_crafter("Smith", "blacksmith", 10)

	# Even with high skill, wrong type should fail
	assert_bool(crafter.can_craft_recipe("enchanter", 1)).is_false()
	assert_bool(crafter.can_craft_recipe("alchemist", 1)).is_false()


# =============================================================================
# AVAILABILITY TESTS
# =============================================================================

func test_is_available_with_no_restrictions() -> void:
	var crafter: CrafterData = _create_crafter()

	assert_bool(crafter.is_available(_no_flags)).is_true()
	assert_bool(crafter.is_available(_all_flags)).is_true()


func test_is_available_required_flags_met() -> void:
	var crafter: CrafterData = _create_crafter()
	crafter.required_flags = ["town_liberated", "smithy_rebuilt"] as Array[String]

	var checker: Callable = _flag_checker_from_list(["town_liberated", "smithy_rebuilt"] as Array[String])

	assert_bool(crafter.is_available(checker)).is_true()


func test_is_available_required_flags_not_met() -> void:
	var crafter: CrafterData = _create_crafter()
	crafter.required_flags = ["town_liberated", "smithy_rebuilt"] as Array[String]

	var checker: Callable = _flag_checker_from_list(["town_liberated"] as Array[String])

	assert_bool(crafter.is_available(checker)).is_false()


func test_is_available_forbidden_flags_set() -> void:
	var crafter: CrafterData = _create_crafter()
	crafter.forbidden_flags = ["crafter_died", "town_destroyed"] as Array[String]

	var checker: Callable = _flag_checker_from_list(["crafter_died"] as Array[String])

	assert_bool(crafter.is_available(checker)).is_false()


func test_is_available_forbidden_flags_not_set() -> void:
	var crafter: CrafterData = _create_crafter()
	crafter.forbidden_flags = ["crafter_died"] as Array[String]

	assert_bool(crafter.is_available(_no_flags)).is_true()


func test_is_available_combined_flags() -> void:
	var crafter: CrafterData = _create_crafter()
	crafter.required_flags = ["hired_crafter"] as Array[String]
	crafter.forbidden_flags = ["crafter_retired"] as Array[String]

	# Has required, no forbidden
	var valid: Callable = _flag_checker_from_list(["hired_crafter"] as Array[String])
	assert_bool(crafter.is_available(valid)).is_true()

	# Has required AND forbidden
	var invalid: Callable = _flag_checker_from_list(["hired_crafter", "crafter_retired"] as Array[String])
	assert_bool(crafter.is_available(invalid)).is_false()


# =============================================================================
# SPECIALIZATION TESTS
# =============================================================================

func test_has_specialization_true() -> void:
	var crafter: CrafterData = _create_crafter("Fire Master", "enchanter", 5)
	crafter.specializations = ["fire", "destruction"] as Array[String]

	assert_bool(crafter.has_specialization("fire")).is_true()
	assert_bool(crafter.has_specialization("destruction")).is_true()


func test_has_specialization_false() -> void:
	var crafter: CrafterData = _create_crafter("Fire Master", "enchanter", 5)
	crafter.specializations = ["fire"] as Array[String]

	assert_bool(crafter.has_specialization("ice")).is_false()
	assert_bool(crafter.has_specialization("holy")).is_false()


func test_has_specialization_empty_list() -> void:
	var crafter: CrafterData = _create_crafter()

	assert_bool(crafter.has_specialization("anything")).is_false()


# =============================================================================
# COST MODIFICATION TESTS
# =============================================================================

func test_get_modified_cost_normal() -> void:
	var crafter: CrafterData = _create_crafter()
	crafter.service_fee_modifier = 1.0

	assert_int(crafter.get_modified_cost(100)).is_equal(100)
	assert_int(crafter.get_modified_cost(250)).is_equal(250)


func test_get_modified_cost_discount() -> void:
	var crafter: CrafterData = _create_crafter()
	crafter.service_fee_modifier = 0.8

	assert_int(crafter.get_modified_cost(100)).is_equal(80)
	assert_int(crafter.get_modified_cost(250)).is_equal(200)


func test_get_modified_cost_premium() -> void:
	var crafter: CrafterData = _create_crafter()
	crafter.service_fee_modifier = 1.5

	assert_int(crafter.get_modified_cost(100)).is_equal(150)
	assert_int(crafter.get_modified_cost(200)).is_equal(300)


func test_get_modified_cost_zero_base() -> void:
	var crafter: CrafterData = _create_crafter()
	crafter.service_fee_modifier = 2.0

	assert_int(crafter.get_modified_cost(0)).is_equal(0)


# =============================================================================
# VALIDATION TESTS
# =============================================================================

func test_validate_passes_with_required_fields() -> void:
	var crafter: CrafterData = _create_crafter("Valid Smith", "blacksmith", 1)

	assert_bool(crafter.validate()).is_true()


func test_validate_fails_without_name() -> void:
	var crafter: CrafterData = _create_crafter("", "blacksmith", 1)

	assert_bool(crafter.validate()).is_false()


func test_validate_fails_without_type() -> void:
	var crafter: CrafterData = _create_crafter("Nameless", "", 1)

	assert_bool(crafter.validate()).is_false()


func test_validate_fails_with_zero_skill() -> void:
	var crafter: CrafterData = _create_crafter("Unskilled", "blacksmith", 0)

	assert_bool(crafter.validate()).is_false()


func test_validate_fails_with_negative_fee_modifier() -> void:
	var crafter: CrafterData = _create_crafter("Generous", "blacksmith", 1)
	crafter.service_fee_modifier = -0.5

	assert_bool(crafter.validate()).is_false()


func test_validate_fails_with_zero_fee_modifier() -> void:
	var crafter: CrafterData = _create_crafter("Free", "blacksmith", 1)
	crafter.service_fee_modifier = 0.0

	assert_bool(crafter.validate()).is_false()


func test_validate_passes_with_high_skill() -> void:
	var crafter: CrafterData = _create_crafter("Master", "blacksmith", 99)

	assert_bool(crafter.validate()).is_true()
