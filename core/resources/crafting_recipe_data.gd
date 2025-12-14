class_name CraftingRecipeData
extends Resource

## Represents a crafting recipe that transforms rare materials into items.
## Supports deterministic crafting with three output modes:
## - SINGLE: One specific item output (most common)
## - CHOICE: Player chooses from multiple options
## - UPGRADE: Enhances an existing item the player owns

enum OutputMode {
	SINGLE,   ## Recipe produces one specific item
	CHOICE,   ## Player chooses output from available options
	UPGRADE   ## Recipe transforms an existing item into a better version
}

@export var recipe_name: String = ""

@export_group("Output")
@export var output_mode: OutputMode = OutputMode.SINGLE
## For SINGLE mode: the item produced
@export var output_item_id: String = ""
## For CHOICE mode: item IDs the player can pick from
@export var output_choices: Array[String] = []
## For UPGRADE mode: the item being enhanced (player must own this)
@export var upgrade_base_item_id: String = ""
## For UPGRADE mode: what the base item becomes
@export var upgrade_result_item_id: String = ""

@export_group("Inputs")
## Required materials: Array of {material_id: String, quantity: int}
@export var inputs: Array[Dictionary] = []
## Gold cost to craft
@export var gold_cost: int = 0

@export_group("Requirements")
## Crafter type needed (e.g., "blacksmith", "enchanter")
@export var required_crafter_type: String = ""
## Minimum crafter skill level needed
@export var required_crafter_skill: int = 1
## Story flags needed to unlock this recipe
@export var required_flags: Array[String] = []

@export_group("Description")
@export_multiline var description: String = ""
## Hint shown if recipe is locked
@export var unlock_hint: String = ""


## Check if player can afford this recipe (materials + gold)
## inventory_checker: Callable(material_id: String) -> int (returns quantity owned)
func can_afford(inventory_checker: Callable, gold_available: int) -> bool:
	if gold_available < gold_cost:
		return false

	for input: Dictionary in inputs:
		var material_id: String = input.get("material_id", "")
		var required_qty: int = input.get("quantity", 1)
		var owned_qty: int = inventory_checker.call(material_id)
		if owned_qty < required_qty:
			return false

	return true


## Get list of missing materials for UI display
## Returns Array of {material_id, required, owned, missing}
func get_missing_materials(inventory_checker: Callable) -> Array[Dictionary]:
	var missing: Array[Dictionary] = []

	for input: Dictionary in inputs:
		var material_id: String = input.get("material_id", "")
		var required_qty: int = input.get("quantity", 1)
		var owned_qty: int = inventory_checker.call(material_id)

		if owned_qty < required_qty:
			missing.append({
				"material_id": material_id,
				"required": required_qty,
				"owned": owned_qty,
				"missing": required_qty - owned_qty
			})

	return missing


## Check if recipe requirements are met (crafter capability + story flags)
func meets_requirements(crafter: CrafterData, flag_checker: Callable) -> bool:
	# Check crafter can perform this recipe
	if not crafter.can_craft_recipe(required_crafter_type, required_crafter_skill):
		return false

	# Check story flags
	for flag: String in required_flags:
		if not flag_checker.call(flag):
			return false

	return true


## Get the output item ID(s) based on mode
## For CHOICE mode, returns all options; caller handles selection
func get_output_item_ids() -> Array[String]:
	var result: Array[String] = []
	match output_mode:
		OutputMode.SINGLE:
			if not output_item_id.is_empty():
				result.append(output_item_id)
		OutputMode.CHOICE:
			result = output_choices.duplicate()
		OutputMode.UPGRADE:
			if not upgrade_result_item_id.is_empty():
				result.append(upgrade_result_item_id)
	return result


## Validate recipe configuration
func validate() -> bool:
	if recipe_name.is_empty():
		push_error("CraftingRecipeData: recipe_name is required")
		return false

	if inputs.is_empty():
		push_error("CraftingRecipeData: at least one input material is required")
		return false

	# Validate input entries
	for i: int in inputs.size():
		var input: Dictionary = inputs[i]
		if "material_id" not in input or input["material_id"].is_empty():
			push_error("CraftingRecipeData: input[%d] missing material_id" % i)
			return false
		if "quantity" not in input or input["quantity"] < 1:
			push_error("CraftingRecipeData: input[%d] quantity must be at least 1" % i)
			return false

	# Validate output based on mode
	match output_mode:
		OutputMode.SINGLE:
			if output_item_id.is_empty():
				push_error("CraftingRecipeData: SINGLE mode requires output_item_id")
				return false
		OutputMode.CHOICE:
			if output_choices.size() < 2:
				push_error("CraftingRecipeData: CHOICE mode requires at least 2 output_choices")
				return false
		OutputMode.UPGRADE:
			if upgrade_base_item_id.is_empty():
				push_error("CraftingRecipeData: UPGRADE mode requires upgrade_base_item_id")
				return false
			if upgrade_result_item_id.is_empty():
				push_error("CraftingRecipeData: UPGRADE mode requires upgrade_result_item_id")
				return false

	if gold_cost < 0:
		push_error("CraftingRecipeData: gold_cost cannot be negative")
		return false

	if required_crafter_skill < 1:
		push_error("CraftingRecipeData: required_crafter_skill must be at least 1")
		return false

	return true
