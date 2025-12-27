extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## CrafterConfirm - Final confirmation for crafting a recipe
##
## Shows: Recipe name, materials consumed, gold cost, output item
## Executes the craft via CraftingManager on confirm.

const COLOR_GOLD: Color = Color(0.8, 0.8, 0.2, 1.0)
const COLOR_OUTPUT: Color = Color(0.6, 0.9, 0.6, 1.0)

@onready var confirm_label: Label = %ConfirmLabel
@onready var recipe_label: Label = %RecipeLabel
@onready var output_label: Label = %OutputLabel
@onready var materials_label: Label = %MaterialsLabel
@onready var cost_label: Label = %CostLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton

## Cached recipe and crafter
var _recipe: CraftingRecipeData = null
var _crafter: CrafterData = null
var _modified_cost: int = 0


func _on_initialized() -> void:
	_recipe = context.get_selected_recipe()
	_crafter = context.get_crafter_data()

	if not _recipe:
		push_error("CrafterConfirm: No recipe selected")
		go_back()
		return

	_modified_cost = _recipe.gold_cost
	if _crafter:
		_modified_cost = _crafter.get_modified_cost(_recipe.gold_cost)

	_populate_display()

	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

	await get_tree().process_frame
	confirm_button.grab_focus()


func _populate_display() -> void:
	confirm_label.text = "CONFIRM CRAFTING"
	recipe_label.text = _recipe.recipe_name.to_upper()

	# Output display
	var output_text: String = ""
	match _recipe.output_mode:
		CraftingRecipeData.OutputMode.SINGLE:
			var item: ItemData = get_item_data(_recipe.output_item_id)
			var name: String = item.item_name if item else _recipe.output_item_id
			output_text = "Create: %s" % name
		CraftingRecipeData.OutputMode.CHOICE:
			output_text = "Create: (choose from %d options)" % _recipe.output_choices.size()
		CraftingRecipeData.OutputMode.UPGRADE:
			var base: ItemData = get_item_data(_recipe.upgrade_base_item_id)
			var result: ItemData = get_item_data(_recipe.upgrade_result_item_id)
			var base_name: String = base.item_name if base else _recipe.upgrade_base_item_id
			var result_name: String = result.item_name if result else _recipe.upgrade_result_item_id
			output_text = "Upgrade: %s -> %s" % [base_name, result_name]
	output_label.text = output_text
	output_label.add_theme_color_override("font_color", COLOR_OUTPUT)

	# Materials consumed
	var materials_lines: Array[String] = []
	materials_lines.append("Materials Consumed:")
	for input: Dictionary in _recipe.inputs:
		var material_id: String = DictUtils.get_string(input, "material_id", "")
		var qty: int = DictUtils.get_int(input, "quantity", 1)
		var item: ItemData = get_item_data(material_id)
		var name: String = item.item_name if item else material_id
		materials_lines.append("  - %s x%d" % [name, qty])
	materials_label.text = "\n".join(materials_lines)

	# Cost
	cost_label.text = "Cost: %dG" % _modified_cost
	cost_label.add_theme_color_override("font_color", COLOR_GOLD)


func _on_confirm_pressed() -> void:
	# Execute crafting via CraftingManager
	if not CraftingManager:
		push_error("CrafterConfirm: CraftingManager not available")
		_show_error("Crafting system unavailable")
		return

	# For CHOICE mode, we'd need to handle selection - for now just use first choice
	var choice_index: int = context.selected_output_index

	var result: Dictionary = CraftingManager.craft_recipe(_recipe, _crafter, choice_index)

	if DictUtils.get_bool(result, "success", false):
		context.set_result("craft_complete", {
			"recipe_name": _recipe.recipe_name,
			"output_item_id": DictUtils.get_string(result, "output_item_id", ""),
			"output_item_name": DictUtils.get_string(result, "output_item_name", ""),
			"gold_spent": DictUtils.get_int(result, "gold_spent", 0),
			"destination": DictUtils.get_string(result, "destination", "")
		})
		replace_with("transaction_result")
	else:
		_show_error(DictUtils.get_string(result, "error", "Unknown error"))


func _show_error(error_msg: String) -> void:
	context.set_result("craft_failed", {
		"error": error_msg
	})
	replace_with("transaction_result")


func _on_cancel_pressed() -> void:
	go_back()


func _on_back_requested() -> void:
	go_back()


## Clean up signal connections when exiting screen
func _on_screen_exit() -> void:
	if is_instance_valid(confirm_button) and confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.disconnect(_on_confirm_pressed)
	if is_instance_valid(cancel_button) and cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.disconnect(_on_cancel_pressed)
