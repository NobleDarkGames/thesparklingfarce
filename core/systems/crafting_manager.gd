extends Node

## CraftingManager - Autoload singleton for executing crafting transactions
##
## Handles:
## - Checking if player can afford a recipe (materials + gold)
## - Executing crafting: deduct materials, deduct gold, grant output item
## - Material counting across Caravan (StorageManager) AND party inventories
##
## Crafting is DETERMINISTIC: bring materials, get item. No failure chances.
##
## Usage:
##   if CraftingManager.can_craft_recipe(recipe):
##       var result = CraftingManager.craft_recipe(recipe, crafter)

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when a crafting transaction completes successfully
signal craft_completed(recipe: CraftingRecipeData, output_item_id: String)

## Emitted when a crafting transaction fails
signal craft_failed(recipe: CraftingRecipeData, reason: String)

# ============================================================================
# MATERIAL COUNTING
# ============================================================================

## Count how many of a material the player owns across all storage
## Checks: Caravan depot + all party member inventories
## @param material_id: ID of the item to count
## @return: Total quantity owned
func count_material(material_id: String) -> int:
	var count: int = 0

	# Check caravan storage
	if StorageManager:
		count += StorageManager.get_item_count(material_id)

	# Check all party member inventories
	if PartyManager:
		for character: CharacterData in PartyManager.party_members:
			var save_data: CharacterSaveData = PartyManager.get_member_save_data(character.character_uid)
			if save_data:
				for item_id: String in save_data.inventory:
					if item_id == material_id:
						count += 1

	return count


## Callable wrapper for count_material (used by recipe.can_afford())
func get_inventory_checker() -> Callable:
	return count_material


# ============================================================================
# AFFORDABILITY CHECKS
# ============================================================================

## Check if player can afford to craft a recipe
## @param recipe: The CraftingRecipeData to check
## @param crafter: Optional CrafterData for cost modification
## @return: true if player has all materials and gold
func can_craft_recipe(recipe: CraftingRecipeData, crafter: CrafterData = null) -> bool:
	if not recipe:
		return false

	# Get current gold
	var gold: int = _get_current_gold()

	# Apply crafter's fee modifier if present
	var modified_cost: int = recipe.gold_cost
	if crafter:
		modified_cost = crafter.get_modified_cost(recipe.gold_cost)

	# Use recipe's built-in can_afford with our inventory checker
	return recipe.can_afford(get_inventory_checker(), gold - modified_cost + recipe.gold_cost)
	# Note: The above looks odd but can_afford checks gold_cost against the passed gold
	# We need to check against modified_cost, so we adjust


## More direct affordability check
func can_afford_recipe(recipe: CraftingRecipeData, crafter: CrafterData = null) -> bool:
	if not recipe:
		return false

	var gold: int = _get_current_gold()
	var modified_cost: int = recipe.gold_cost
	if crafter:
		modified_cost = crafter.get_modified_cost(recipe.gold_cost)

	# Check gold
	if gold < modified_cost:
		return false

	# Check each material
	for input: Dictionary in recipe.inputs:
		var material_id: String = input.get("material_id", "")
		var required_qty: int = input.get("quantity", 1)
		var owned_qty: int = count_material(material_id)
		if owned_qty < required_qty:
			return false

	return true


## Get list of recipes the player can currently afford
## @param crafter: Optional CrafterData to filter by crafter capabilities
## @return: Array of CraftingRecipeData the player can craft
func get_available_recipes(crafter: CrafterData = null) -> Array[CraftingRecipeData]:
	var available: Array[CraftingRecipeData] = []
	var all_recipes: Array = ModLoader.registry.get_all_resources("crafting_recipe")

	for recipe: CraftingRecipeData in all_recipes:
		if not recipe:
			continue

		# Check crafter capability if specified
		if crafter and not crafter.can_craft_recipe(recipe.required_crafter_type, recipe.required_crafter_skill):
			continue

		# Check story requirements
		var meets_flags: bool = true
		for flag: String in recipe.required_flags:
			if not GameState.has_flag(flag):
				meets_flags = false
				break
		if not meets_flags:
			continue

		# Check affordability
		if can_afford_recipe(recipe, crafter):
			available.append(recipe)

	return available


# ============================================================================
# CRAFTING EXECUTION
# ============================================================================

## Execute a crafting recipe
## Deducts materials and gold, grants output item
## @param recipe: The CraftingRecipeData to craft
## @param crafter: Optional CrafterData for cost modification
## @param choice_index: For CHOICE mode recipes, which output to select (0-indexed)
## @return: Dictionary with {success, output_item_id, output_item_name, gold_spent, destination, error}
func craft_recipe(recipe: CraftingRecipeData, crafter: CrafterData = null, choice_index: int = 0) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"output_item_id": "",
		"output_item_name": "",
		"gold_spent": 0,
		"destination": "caravan",
		"error": ""
	}

	if not recipe:
		result.error = "Invalid recipe"
		craft_failed.emit(null, result.error)
		return result

	# Calculate modified cost
	var modified_cost: int = recipe.gold_cost
	if crafter:
		modified_cost = crafter.get_modified_cost(recipe.gold_cost)

	# Final affordability check
	if not can_afford_recipe(recipe, crafter):
		result.error = "Cannot afford recipe"
		craft_failed.emit(recipe, result.error)
		return result

	# Determine output item
	var output_item_id: String = _determine_output_item(recipe, choice_index)
	if output_item_id.is_empty():
		result.error = "Could not determine output item"
		craft_failed.emit(recipe, result.error)
		return result

	# UPGRADE mode: Check player owns the base item
	if recipe.output_mode == CraftingRecipeData.OutputMode.UPGRADE:
		if count_material(recipe.upgrade_base_item_id) < 1:
			result.error = "You don't own the item to upgrade"
			craft_failed.emit(recipe, result.error)
			return result

	# === EXECUTE TRANSACTION (ATOMIC) ===
	# Verify output can be stored BEFORE consuming anything
	
	# 1. Pre-flight check: Ensure we can add the output item
	if not _can_add_item_to_caravan(output_item_id):
		result.error = "Caravan storage is full"
		craft_failed.emit(recipe, result.error)
		return result

	# 2. Deduct gold (safe to proceed now)
	_deduct_gold(modified_cost)
	result.gold_spent = modified_cost

	# 3. Deduct materials
	for input: Dictionary in recipe.inputs:
		var material_id: String = input.get("material_id", "")
		var qty: int = input.get("quantity", 1)
		_remove_materials(material_id, qty)

	# 4. For UPGRADE mode, also remove the base item
	if recipe.output_mode == CraftingRecipeData.OutputMode.UPGRADE:
		_remove_materials(recipe.upgrade_base_item_id, 1)

	# 5. Grant output item (to caravan) - should always succeed after pre-flight
	var add_success: bool = _add_item_to_caravan(output_item_id)
	if not add_success:
		# This should never happen after pre-flight check, but log if it does
		push_error("CraftingManager: _add_item_to_caravan failed after pre-flight check passed")
		result.error = "Failed to store crafted item"
		craft_failed.emit(recipe, result.error)
		return result

	# Success!
	result.success = true
	result.output_item_id = output_item_id
	result.destination = "caravan"

	# Get item name for display
	var item_data: ItemData = ModLoader.registry.get_item(output_item_id)
	result.output_item_name = item_data.item_name if item_data else output_item_id

	craft_completed.emit(recipe, output_item_id)
	return result


## Determine which item to output based on recipe mode
func _determine_output_item(recipe: CraftingRecipeData, choice_index: int) -> String:
	match recipe.output_mode:
		CraftingRecipeData.OutputMode.SINGLE:
			return recipe.output_item_id

		CraftingRecipeData.OutputMode.CHOICE:
			if choice_index >= 0 and choice_index < recipe.output_choices.size():
				return recipe.output_choices[choice_index]
			elif recipe.output_choices.size() > 0:
				return recipe.output_choices[0]  # Fallback to first
			return ""

		CraftingRecipeData.OutputMode.UPGRADE:
			return recipe.upgrade_result_item_id

	return ""


# ============================================================================
# PRIVATE HELPERS
# ============================================================================

## Get current gold
func _get_current_gold() -> int:
	if SaveManager and SaveManager.current_save:
		return SaveManager.current_save.gold
	return 0


## Deduct gold from player
func _deduct_gold(amount: int) -> void:
	if SaveManager and SaveManager.current_save:
		SaveManager.current_save.gold = maxi(0, SaveManager.current_save.gold - amount)


## Remove materials from storage, prioritizing caravan then party inventories
## @param material_id: ID of the material to remove
## @param quantity: How many to remove
func _remove_materials(material_id: String, quantity: int) -> void:
	var remaining: int = quantity

	# First, remove from caravan
	if StorageManager and remaining > 0:
		var in_caravan: int = StorageManager.get_item_count(material_id)
		var to_remove: int = mini(in_caravan, remaining)
		for i: int in range(to_remove):
			StorageManager.remove_from_depot(material_id)
		remaining -= to_remove

	# Then, remove from party inventories
	if PartyManager and remaining > 0:
		for character: CharacterData in PartyManager.party_members:
			if remaining <= 0:
				break

			var save_data: CharacterSaveData = PartyManager.get_member_save_data(character.character_uid)
			if not save_data:
				continue

			# Count how many this character has
			var count_in_inv: int = 0
			for item_id: String in save_data.inventory:
				if item_id == material_id:
					count_in_inv += 1

			# Remove up to remaining needed
			var to_remove: int = mini(count_in_inv, remaining)
			for i: int in range(to_remove):
				save_data.remove_item_from_inventory(material_id)
			remaining -= to_remove


## Check if an item can be added to caravan storage (pre-flight check)
## @param item_id: ID of the item to add
## @return: true if the item can be added
func _can_add_item_to_caravan(item_id: String) -> bool:
	if item_id.is_empty():
		return false
	if not StorageManager:
		return false
	return not StorageManager.is_full()


## Add an item to caravan storage
## @param item_id: ID of the item to add
## @return: true if successful
func _add_item_to_caravan(item_id: String) -> bool:
	if not StorageManager:
		push_error("CraftingManager: StorageManager not available")
		return false

	return StorageManager.add_to_depot(item_id)


# ============================================================================
# DEBUG
# ============================================================================

## Get debug info about crafting capabilities
func get_debug_string() -> String:
	var output: String = "CraftingManager Status:\n"

	var all_recipes: Array[Resource] = ModLoader.registry.get_all_resources("crafting_recipe")
	output += "  Total Recipes: %d\n" % all_recipes.size()

	var affordable: Array[CraftingRecipeData] = get_available_recipes()
	output += "  Affordable Now: %d\n" % affordable.size()

	output += "  Current Gold: %d\n" % _get_current_gold()

	return output
