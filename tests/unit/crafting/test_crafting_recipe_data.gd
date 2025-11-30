## Unit Tests for CraftingRecipeData Resource
##
## Tests the crafting recipe data with all three output modes.
class_name TestCraftingRecipeData
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

func _create_single_recipe(
	recipe_name: String = "Iron Sword",
	output: String = "iron_sword",
	inputs: Array[Dictionary] = []
) -> CraftingRecipeData:
	var recipe: CraftingRecipeData = CraftingRecipeData.new()
	recipe.recipe_name = recipe_name
	recipe.output_mode = CraftingRecipeData.OutputMode.SINGLE
	recipe.output_item_id = output
	if inputs.is_empty():
		recipe.inputs = [{"material_id": "iron_ore", "quantity": 2}]
	else:
		recipe.inputs = inputs
	return recipe


func _create_choice_recipe(choices: Array[String]) -> CraftingRecipeData:
	var recipe: CraftingRecipeData = CraftingRecipeData.new()
	recipe.recipe_name = "Mithril Weapon"
	recipe.output_mode = CraftingRecipeData.OutputMode.CHOICE
	recipe.output_choices = choices
	recipe.inputs = [{"material_id": "mithril", "quantity": 1}]
	return recipe


func _create_upgrade_recipe(base: String, result: String) -> CraftingRecipeData:
	var recipe: CraftingRecipeData = CraftingRecipeData.new()
	recipe.recipe_name = "Upgrade: " + base
	recipe.output_mode = CraftingRecipeData.OutputMode.UPGRADE
	recipe.upgrade_base_item_id = base
	recipe.upgrade_result_item_id = result
	recipe.inputs = [{"material_id": "power_shard", "quantity": 1}]
	return recipe


func _create_crafter(crafter_type: String, skill: int) -> CrafterData:
	var crafter: CrafterData = CrafterData.new()
	crafter.crafter_name = "Test Crafter"
	crafter.crafter_type = crafter_type
	crafter.skill_level = skill
	return crafter


## Create inventory checker from material counts
func _inventory_from_dict(inventory: Dictionary) -> Callable:
	return func(material_id: String) -> int:
		return inventory.get(material_id, 0)


## Flag checker that always returns false
func _no_flags(_flag: String) -> bool:
	return false


## Flag checker from list
func _flag_checker_from_list(flags: Array[String]) -> Callable:
	return func(flag: String) -> bool:
		return flag in flags


# =============================================================================
# BASIC PROPERTY TESTS
# =============================================================================

func test_default_values() -> void:
	var recipe: CraftingRecipeData = CraftingRecipeData.new()

	assert_str(recipe.recipe_name).is_equal("")
	assert_int(recipe.output_mode).is_equal(CraftingRecipeData.OutputMode.SINGLE)
	assert_str(recipe.output_item_id).is_equal("")
	assert_array(recipe.output_choices).is_empty()
	assert_array(recipe.inputs).is_empty()
	assert_int(recipe.gold_cost).is_equal(0)
	assert_int(recipe.required_crafter_skill).is_equal(1)


func test_single_mode_properties() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe("Steel Sword", "steel_sword")

	assert_int(recipe.output_mode).is_equal(CraftingRecipeData.OutputMode.SINGLE)
	assert_str(recipe.output_item_id).is_equal("steel_sword")


func test_choice_mode_properties() -> void:
	var recipe: CraftingRecipeData = _create_choice_recipe(
		["mithril_sword", "mithril_axe", "mithril_spear"] as Array[String]
	)

	assert_int(recipe.output_mode).is_equal(CraftingRecipeData.OutputMode.CHOICE)
	assert_int(recipe.output_choices.size()).is_equal(3)


func test_upgrade_mode_properties() -> void:
	var recipe: CraftingRecipeData = _create_upgrade_recipe("iron_sword", "steel_sword")

	assert_int(recipe.output_mode).is_equal(CraftingRecipeData.OutputMode.UPGRADE)
	assert_str(recipe.upgrade_base_item_id).is_equal("iron_sword")
	assert_str(recipe.upgrade_result_item_id).is_equal("steel_sword")


# =============================================================================
# CAN AFFORD TESTS
# =============================================================================

func test_can_afford_with_exact_materials() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.inputs = [{"material_id": "iron_ore", "quantity": 2}]
	recipe.gold_cost = 100

	var inventory: Callable = _inventory_from_dict({"iron_ore": 2})

	assert_bool(recipe.can_afford(inventory, 100)).is_true()


func test_can_afford_with_excess_materials() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.inputs = [{"material_id": "iron_ore", "quantity": 2}]
	recipe.gold_cost = 100

	var inventory: Callable = _inventory_from_dict({"iron_ore": 10})

	assert_bool(recipe.can_afford(inventory, 500)).is_true()


func test_can_afford_insufficient_materials() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.inputs = [{"material_id": "iron_ore", "quantity": 5}]
	recipe.gold_cost = 0

	var inventory: Callable = _inventory_from_dict({"iron_ore": 3})

	assert_bool(recipe.can_afford(inventory, 1000)).is_false()


func test_can_afford_insufficient_gold() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.inputs = [{"material_id": "iron_ore", "quantity": 1}]
	recipe.gold_cost = 500

	var inventory: Callable = _inventory_from_dict({"iron_ore": 10})

	assert_bool(recipe.can_afford(inventory, 100)).is_false()


func test_can_afford_multiple_materials() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.inputs = [
		{"material_id": "mithril", "quantity": 1},
		{"material_id": "dragon_scale", "quantity": 2},
		{"material_id": "magic_essence", "quantity": 3}
	]
	recipe.gold_cost = 1000

	# Has all materials
	var has_all: Callable = _inventory_from_dict({
		"mithril": 1,
		"dragon_scale": 5,
		"magic_essence": 3
	})
	assert_bool(recipe.can_afford(has_all, 1000)).is_true()

	# Missing one material
	var missing_one: Callable = _inventory_from_dict({
		"mithril": 1,
		"dragon_scale": 1,  # Need 2
		"magic_essence": 3
	})
	assert_bool(recipe.can_afford(missing_one, 1000)).is_false()


func test_can_afford_zero_gold_cost() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.gold_cost = 0

	var inventory: Callable = _inventory_from_dict({"iron_ore": 10})

	assert_bool(recipe.can_afford(inventory, 0)).is_true()


# =============================================================================
# MISSING MATERIALS TESTS
# =============================================================================

func test_get_missing_materials_none_missing() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.inputs = [{"material_id": "iron_ore", "quantity": 2}]

	var inventory: Callable = _inventory_from_dict({"iron_ore": 5})
	var missing: Array[Dictionary] = recipe.get_missing_materials(inventory)

	assert_array(missing).is_empty()


func test_get_missing_materials_some_missing() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.inputs = [
		{"material_id": "mithril", "quantity": 3},
		{"material_id": "dragon_scale", "quantity": 2}
	]

	var inventory: Callable = _inventory_from_dict({"mithril": 1, "dragon_scale": 5})
	var missing: Array[Dictionary] = recipe.get_missing_materials(inventory)

	assert_int(missing.size()).is_equal(1)
	assert_str(missing[0]["material_id"]).is_equal("mithril")
	assert_int(missing[0]["required"]).is_equal(3)
	assert_int(missing[0]["owned"]).is_equal(1)
	assert_int(missing[0]["missing"]).is_equal(2)


func test_get_missing_materials_all_missing() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.inputs = [
		{"material_id": "mithril", "quantity": 1},
		{"material_id": "dragon_scale", "quantity": 1}
	]

	var inventory: Callable = _inventory_from_dict({})
	var missing: Array[Dictionary] = recipe.get_missing_materials(inventory)

	assert_int(missing.size()).is_equal(2)


# =============================================================================
# MEETS REQUIREMENTS TESTS
# =============================================================================

func test_meets_requirements_matching_crafter() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.required_crafter_type = "blacksmith"
	recipe.required_crafter_skill = 2

	var crafter: CrafterData = _create_crafter("blacksmith", 3)

	assert_bool(recipe.meets_requirements(crafter, _no_flags)).is_true()


func test_meets_requirements_wrong_crafter_type() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.required_crafter_type = "enchanter"
	recipe.required_crafter_skill = 1

	var crafter: CrafterData = _create_crafter("blacksmith", 10)

	assert_bool(recipe.meets_requirements(crafter, _no_flags)).is_false()


func test_meets_requirements_insufficient_skill() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.required_crafter_type = "blacksmith"
	recipe.required_crafter_skill = 5

	var crafter: CrafterData = _create_crafter("blacksmith", 3)

	assert_bool(recipe.meets_requirements(crafter, _no_flags)).is_false()


func test_meets_requirements_with_flags() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.required_crafter_type = "blacksmith"
	recipe.required_crafter_skill = 1
	recipe.required_flags = ["learned_ancient_technique"] as Array[String]

	var crafter: CrafterData = _create_crafter("blacksmith", 5)

	# Without required flag
	assert_bool(recipe.meets_requirements(crafter, _no_flags)).is_false()

	# With required flag
	var has_flag: Callable = _flag_checker_from_list(["learned_ancient_technique"] as Array[String])
	assert_bool(recipe.meets_requirements(crafter, has_flag)).is_true()


# =============================================================================
# GET OUTPUT ITEM IDS TESTS
# =============================================================================

func test_get_output_item_ids_single_mode() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe("Test", "legendary_sword")

	var outputs: Array[String] = recipe.get_output_item_ids()

	assert_int(outputs.size()).is_equal(1)
	assert_str(outputs[0]).is_equal("legendary_sword")


func test_get_output_item_ids_choice_mode() -> void:
	var recipe: CraftingRecipeData = _create_choice_recipe(
		["sword", "axe", "spear"] as Array[String]
	)

	var outputs: Array[String] = recipe.get_output_item_ids()

	assert_int(outputs.size()).is_equal(3)
	assert_array(outputs).contains(["sword", "axe", "spear"])


func test_get_output_item_ids_upgrade_mode() -> void:
	var recipe: CraftingRecipeData = _create_upgrade_recipe("basic_sword", "enhanced_sword")

	var outputs: Array[String] = recipe.get_output_item_ids()

	assert_int(outputs.size()).is_equal(1)
	assert_str(outputs[0]).is_equal("enhanced_sword")


# =============================================================================
# VALIDATION TESTS - GENERAL
# =============================================================================

func test_validate_fails_without_name() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.recipe_name = ""

	assert_bool(recipe.validate()).is_false()


func test_validate_fails_without_inputs() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.inputs = []

	assert_bool(recipe.validate()).is_false()


func test_validate_fails_with_invalid_input_entry() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.inputs = [{"material_id": "", "quantity": 1}]

	assert_bool(recipe.validate()).is_false()


func test_validate_fails_with_zero_quantity_input() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.inputs = [{"material_id": "iron", "quantity": 0}]

	assert_bool(recipe.validate()).is_false()


func test_validate_fails_with_negative_gold() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.gold_cost = -100

	assert_bool(recipe.validate()).is_false()


func test_validate_fails_with_zero_required_skill() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe()
	recipe.required_crafter_skill = 0

	assert_bool(recipe.validate()).is_false()


# =============================================================================
# VALIDATION TESTS - SINGLE MODE
# =============================================================================

func test_validate_single_mode_passes() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe("Valid Recipe", "output_item")

	assert_bool(recipe.validate()).is_true()


func test_validate_single_mode_fails_without_output() -> void:
	var recipe: CraftingRecipeData = _create_single_recipe("No Output", "")

	assert_bool(recipe.validate()).is_false()


# =============================================================================
# VALIDATION TESTS - CHOICE MODE
# =============================================================================

func test_validate_choice_mode_passes() -> void:
	var recipe: CraftingRecipeData = _create_choice_recipe(
		["option_a", "option_b"] as Array[String]
	)

	assert_bool(recipe.validate()).is_true()


func test_validate_choice_mode_fails_with_one_option() -> void:
	var recipe: CraftingRecipeData = _create_choice_recipe(
		["only_one"] as Array[String]
	)

	assert_bool(recipe.validate()).is_false()


func test_validate_choice_mode_fails_with_no_options() -> void:
	var recipe: CraftingRecipeData = CraftingRecipeData.new()
	recipe.recipe_name = "No Choices"
	recipe.output_mode = CraftingRecipeData.OutputMode.CHOICE
	recipe.output_choices = [] as Array[String]
	recipe.inputs = [{"material_id": "stuff", "quantity": 1}]

	assert_bool(recipe.validate()).is_false()


# =============================================================================
# VALIDATION TESTS - UPGRADE MODE
# =============================================================================

func test_validate_upgrade_mode_passes() -> void:
	var recipe: CraftingRecipeData = _create_upgrade_recipe("base_item", "upgraded_item")

	assert_bool(recipe.validate()).is_true()


func test_validate_upgrade_mode_fails_without_base() -> void:
	var recipe: CraftingRecipeData = _create_upgrade_recipe("", "upgraded_item")

	assert_bool(recipe.validate()).is_false()


func test_validate_upgrade_mode_fails_without_result() -> void:
	var recipe: CraftingRecipeData = _create_upgrade_recipe("base_item", "")

	assert_bool(recipe.validate()).is_false()
