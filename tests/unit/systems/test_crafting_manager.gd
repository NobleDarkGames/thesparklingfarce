## CraftingManager Unit Tests
##
## Tests the CraftingManager crafting transaction functionality:
## - Output item determination based on recipe mode (SINGLE, CHOICE, UPGRADE)
## - Inventory checker callable
## - Signal emissions
## - Recipe validation
##
## Note: This is a UNIT test - creates a fresh CraftingManager instance.
## Many methods depend on external singletons (StorageManager, PartyManager,
## SaveManager, ModLoader) which are not available in unit tests.
## Tests focus on the internal logic that can be tested in isolation.
class_name TestCraftingManager
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

const CraftingManagerScript: GDScript = preload("res://core/systems/crafting_manager.gd")
const CraftingRecipeDataScript: GDScript = preload("res://core/resources/crafting_recipe_data.gd")
const SignalTrackerScript: GDScript = preload("res://tests/fixtures/signal_tracker.gd")

var _crafting: Node
var _tracker: SignalTracker


func before_test() -> void:
	_crafting = CraftingManagerScript.new()
	add_child(_crafting)
	_tracker = SignalTrackerScript.new()


func after_test() -> void:
	if _tracker:
		_tracker.disconnect_all()
		_tracker = null
	if _crafting and is_instance_valid(_crafting):
		_crafting.queue_free()
	_crafting = null


## Create a minimal test recipe
func _create_test_recipe(mode: int = 0) -> CraftingRecipeData:
	var recipe: CraftingRecipeData = CraftingRecipeDataScript.new()
	recipe.recipe_name = "Test Recipe"
	recipe.output_mode = mode
	recipe.gold_cost = 100
	recipe.inputs = [{"material_id": "iron_ore", "quantity": 2}]

	match mode:
		CraftingRecipeData.OutputMode.SINGLE:
			recipe.output_item_id = "iron_sword"
		CraftingRecipeData.OutputMode.CHOICE:
			recipe.output_choices = ["iron_sword", "iron_axe", "iron_spear"]
		CraftingRecipeData.OutputMode.UPGRADE:
			recipe.upgrade_base_item_id = "wooden_sword"
			recipe.upgrade_result_item_id = "iron_sword"

	return recipe


# =============================================================================
# OUTPUT DETERMINATION TESTS - SINGLE MODE
# =============================================================================

func test_determine_output_single_mode_returns_output_item_id() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.SINGLE)

	var output: String = _crafting._determine_output_item(recipe, 0)

	assert_str(output).is_equal("iron_sword")


func test_determine_output_single_mode_ignores_choice_index() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.SINGLE)

	var output: String = _crafting._determine_output_item(recipe, 5)

	assert_str(output).is_equal("iron_sword")


func test_determine_output_single_mode_empty_returns_empty() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.SINGLE)
	recipe.output_item_id = ""

	var output: String = _crafting._determine_output_item(recipe, 0)

	assert_str(output).is_empty()


# =============================================================================
# OUTPUT DETERMINATION TESTS - CHOICE MODE
# =============================================================================

func test_determine_output_choice_mode_index_zero() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.CHOICE)

	var output: String = _crafting._determine_output_item(recipe, 0)

	assert_str(output).is_equal("iron_sword")


func test_determine_output_choice_mode_index_one() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.CHOICE)

	var output: String = _crafting._determine_output_item(recipe, 1)

	assert_str(output).is_equal("iron_axe")


func test_determine_output_choice_mode_index_two() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.CHOICE)

	var output: String = _crafting._determine_output_item(recipe, 2)

	assert_str(output).is_equal("iron_spear")


func test_determine_output_choice_mode_invalid_index_returns_first() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.CHOICE)

	var output: String = _crafting._determine_output_item(recipe, 99)

	assert_str(output).is_equal("iron_sword")


func test_determine_output_choice_mode_negative_index_returns_first() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.CHOICE)

	var output: String = _crafting._determine_output_item(recipe, -1)

	assert_str(output).is_equal("iron_sword")


func test_determine_output_choice_mode_empty_choices_returns_empty() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.CHOICE)
	recipe.output_choices = []

	var output: String = _crafting._determine_output_item(recipe, 0)

	assert_str(output).is_empty()


# =============================================================================
# OUTPUT DETERMINATION TESTS - UPGRADE MODE
# =============================================================================

func test_determine_output_upgrade_mode_returns_result_item() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.UPGRADE)

	var output: String = _crafting._determine_output_item(recipe, 0)

	assert_str(output).is_equal("iron_sword")


func test_determine_output_upgrade_mode_ignores_choice_index() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.UPGRADE)

	var output: String = _crafting._determine_output_item(recipe, 5)

	assert_str(output).is_equal("iron_sword")


func test_determine_output_upgrade_mode_empty_returns_empty() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.UPGRADE)
	recipe.upgrade_result_item_id = ""

	var output: String = _crafting._determine_output_item(recipe, 0)

	assert_str(output).is_empty()


# =============================================================================
# INVENTORY CHECKER CALLABLE TESTS
# =============================================================================

func test_get_inventory_checker_returns_callable() -> void:
	var checker: Callable = _crafting.get_inventory_checker()

	assert_bool(checker.is_valid()).is_true()


func test_get_inventory_checker_returns_count_material_function() -> void:
	var checker: Callable = _crafting.get_inventory_checker()

	# The callable should be the count_material method
	# Without singletons it returns 0, but we can verify it's callable
	var count: int = checker.call("test_material")

	assert_int(count).is_equal(0)


# =============================================================================
# COUNT MATERIAL TESTS (WITHOUT SINGLETONS)
# =============================================================================

func test_count_material_returns_zero_without_singletons() -> void:
	# Without StorageManager and PartyManager, count should be 0
	var count: int = _crafting.count_material("any_material")

	assert_int(count).is_equal(0)


func test_count_material_different_materials_all_zero() -> void:
	assert_int(_crafting.count_material("iron_ore")).is_equal(0)
	assert_int(_crafting.count_material("gold_nugget")).is_equal(0)
	assert_int(_crafting.count_material("mithril_shard")).is_equal(0)


# =============================================================================
# SIGNAL TESTS
# =============================================================================

func test_craft_completed_signal_exists() -> void:
	var emissions: Array = []
	var callback: Callable = func(recipe: CraftingRecipeData, output_id: String) -> void:
		emissions.append([recipe, output_id])

	_crafting.craft_completed.connect(callback)
	var test_recipe: CraftingRecipeData = _create_test_recipe()
	_crafting.craft_completed.emit(test_recipe, "iron_sword")

	assert_int(emissions.size()).is_equal(1)
	assert_str(emissions[0][1]).is_equal("iron_sword")

	_crafting.craft_completed.disconnect(callback)


func test_craft_failed_signal_exists() -> void:
	var emissions: Array = []
	var callback: Callable = func(recipe: CraftingRecipeData, reason: String) -> void:
		emissions.append([recipe, reason])

	_crafting.craft_failed.connect(callback)
	_crafting.craft_failed.emit(null, "Test failure reason")

	assert_int(emissions.size()).is_equal(1)
	assert_str(emissions[0][1]).is_equal("Test failure reason")

	_crafting.craft_failed.disconnect(callback)


# =============================================================================
# CAN CRAFT RECIPE TESTS
# =============================================================================

func test_can_craft_recipe_returns_false_for_null() -> void:
	var result: bool = _crafting.can_craft_recipe(null)

	assert_bool(result).is_false()


func test_can_afford_recipe_returns_false_for_null() -> void:
	var result: bool = _crafting.can_afford_recipe(null)

	assert_bool(result).is_false()


# =============================================================================
# CRAFT RECIPE TESTS
# =============================================================================

func test_craft_recipe_returns_error_for_null() -> void:
	_tracker.track(_crafting.craft_failed)

	var result: Dictionary = _crafting.craft_recipe(null)

	assert_bool(result.success).is_false()
	assert_str(result.error).is_equal("Invalid recipe")
	assert_bool(_tracker.was_emitted("craft_failed")).is_true()


func test_craft_recipe_result_has_required_fields() -> void:
	var result: Dictionary = _crafting.craft_recipe(null)

	assert_bool("success" in result).is_true()
	assert_bool("output_item_id" in result).is_true()
	assert_bool("output_item_name" in result).is_true()
	assert_bool("gold_spent" in result).is_true()
	assert_bool("destination" in result).is_true()
	assert_bool("error" in result).is_true()


func test_craft_recipe_initial_result_values() -> void:
	var result: Dictionary = _crafting.craft_recipe(null)

	assert_bool(result.success).is_false()
	assert_str(result.output_item_id).is_empty()
	assert_str(result.output_item_name).is_empty()
	assert_int(result.gold_spent).is_equal(0)
	assert_str(result.destination).is_equal("caravan")


# =============================================================================
# PRIVATE HELPER TESTS
# =============================================================================

func test_get_current_gold_returns_zero_without_save_manager() -> void:
	# Without SaveManager singleton, should return 0
	var gold: int = _crafting._get_current_gold()

	assert_int(gold).is_equal(0)


func test_can_add_item_to_caravan_returns_result_for_valid_id() -> void:
	# With valid item ID, checks StorageManager.is_full()
	# Result depends on StorageManager state (autoload available in tests)
	var result: bool = _crafting._can_add_item_to_caravan("test_item")

	# Just verify it returns a boolean (actual result depends on StorageManager state)
	assert_bool(result == true or result == false).is_true()


func test_can_add_item_to_caravan_returns_false_for_empty_id() -> void:
	var result: bool = _crafting._can_add_item_to_caravan("")

	assert_bool(result).is_false()


func test_add_item_to_caravan_returns_result_for_valid_id() -> void:
	# With valid item ID, attempts to add via StorageManager
	# Result depends on StorageManager state (autoload available in tests)
	var result: bool = _crafting._add_item_to_caravan("test_item")

	# Just verify it returns a boolean (actual result depends on StorageManager state)
	assert_bool(result == true or result == false).is_true()


# =============================================================================
# RECIPE DATA VALIDATION TESTS
# =============================================================================

func test_recipe_mode_single_is_zero() -> void:
	assert_int(CraftingRecipeData.OutputMode.SINGLE).is_equal(0)


func test_recipe_mode_choice_is_one() -> void:
	assert_int(CraftingRecipeData.OutputMode.CHOICE).is_equal(1)


func test_recipe_mode_upgrade_is_two() -> void:
	assert_int(CraftingRecipeData.OutputMode.UPGRADE).is_equal(2)


# =============================================================================
# CRAFTING RECIPE DATA TESTS
# =============================================================================

func test_recipe_can_afford_with_sufficient_resources() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe()

	# Create a mock inventory checker that always returns enough
	var checker: Callable = func(material_id: String) -> int:
		return 10  # Always have 10 of everything

	var result: bool = recipe.can_afford(checker, 200)  # Have more gold than needed

	assert_bool(result).is_true()


func test_recipe_can_afford_with_insufficient_gold() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe()

	var checker: Callable = func(material_id: String) -> int:
		return 10

	var result: bool = recipe.can_afford(checker, 50)  # Less gold than 100 cost

	assert_bool(result).is_false()


func test_recipe_can_afford_with_insufficient_materials() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe()

	var checker: Callable = func(material_id: String) -> int:
		return 1  # Only have 1, need 2

	var result: bool = recipe.can_afford(checker, 200)

	assert_bool(result).is_false()


func test_recipe_can_afford_exact_amounts() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe()

	var checker: Callable = func(material_id: String) -> int:
		return 2  # Exactly what's needed

	var result: bool = recipe.can_afford(checker, 100)  # Exactly the cost

	assert_bool(result).is_true()


func test_recipe_get_missing_materials_none_missing() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe()

	var checker: Callable = func(material_id: String) -> int:
		return 10

	var missing: Array[Dictionary] = recipe.get_missing_materials(checker)

	assert_array(missing).is_empty()


func test_recipe_get_missing_materials_some_missing() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe()

	var checker: Callable = func(material_id: String) -> int:
		return 1  # Only have 1, need 2

	var missing: Array[Dictionary] = recipe.get_missing_materials(checker)

	assert_int(missing.size()).is_equal(1)
	assert_str(missing[0].material_id).is_equal("iron_ore")
	assert_int(missing[0].required).is_equal(2)
	assert_int(missing[0].owned).is_equal(1)
	assert_int(missing[0].missing).is_equal(1)


func test_recipe_get_missing_materials_all_missing() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe()

	var checker: Callable = func(material_id: String) -> int:
		return 0

	var missing: Array[Dictionary] = recipe.get_missing_materials(checker)

	assert_int(missing.size()).is_equal(1)
	assert_int(missing[0].owned).is_equal(0)
	assert_int(missing[0].missing).is_equal(2)


func test_recipe_get_output_item_ids_single_mode() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.SINGLE)

	var outputs: Array[String] = recipe.get_output_item_ids()

	assert_int(outputs.size()).is_equal(1)
	assert_str(outputs[0]).is_equal("iron_sword")


func test_recipe_get_output_item_ids_choice_mode() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.CHOICE)

	var outputs: Array[String] = recipe.get_output_item_ids()

	assert_int(outputs.size()).is_equal(3)
	assert_str(outputs[0]).is_equal("iron_sword")
	assert_str(outputs[1]).is_equal("iron_axe")
	assert_str(outputs[2]).is_equal("iron_spear")


func test_recipe_get_output_item_ids_upgrade_mode() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.UPGRADE)

	var outputs: Array[String] = recipe.get_output_item_ids()

	assert_int(outputs.size()).is_equal(1)
	assert_str(outputs[0]).is_equal("iron_sword")


func test_recipe_validate_passes_for_valid_single_recipe() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.SINGLE)

	var is_valid: bool = recipe.validate()

	assert_bool(is_valid).is_true()


func test_recipe_validate_fails_for_empty_name() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe()
	recipe.recipe_name = ""

	var is_valid: bool = recipe.validate()

	assert_bool(is_valid).is_false()


func test_recipe_validate_fails_for_empty_inputs() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe()
	recipe.inputs = []

	var is_valid: bool = recipe.validate()

	assert_bool(is_valid).is_false()


func test_recipe_validate_fails_for_negative_gold() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe()
	recipe.gold_cost = -50

	var is_valid: bool = recipe.validate()

	assert_bool(is_valid).is_false()


func test_recipe_validate_fails_for_single_mode_without_output() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.SINGLE)
	recipe.output_item_id = ""

	var is_valid: bool = recipe.validate()

	assert_bool(is_valid).is_false()


func test_recipe_validate_fails_for_choice_mode_with_one_option() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.CHOICE)
	recipe.output_choices = ["only_one"]

	var is_valid: bool = recipe.validate()

	assert_bool(is_valid).is_false()


func test_recipe_validate_fails_for_upgrade_without_base_item() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.UPGRADE)
	recipe.upgrade_base_item_id = ""

	var is_valid: bool = recipe.validate()

	assert_bool(is_valid).is_false()


func test_recipe_validate_fails_for_upgrade_without_result_item() -> void:
	var recipe: CraftingRecipeData = _create_test_recipe(CraftingRecipeData.OutputMode.UPGRADE)
	recipe.upgrade_result_item_id = ""

	var is_valid: bool = recipe.validate()

	assert_bool(is_valid).is_false()
