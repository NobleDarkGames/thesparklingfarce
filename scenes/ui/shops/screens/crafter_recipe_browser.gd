extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## CrafterRecipeBrowser - Browse and select crafting recipes
##
## Displays available recipes filtered by the crafter's type and skill level.
## Shows recipe name, output item, required materials, and gold cost.
## Recipes the player cannot afford are grayed out.

## Colors matching project standards
const COLOR_NORMAL: Color = Color(0.8, 0.8, 0.8, 1.0)
const COLOR_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)  # Bright yellow
const COLOR_DISABLED: Color = Color(0.4, 0.4, 0.4, 1.0)
const COLOR_GOLD: Color = Color(0.8, 0.8, 0.2, 1.0)
const COLOR_MISSING: Color = Color(0.8, 0.3, 0.3, 1.0)

## Currently selected recipe ID
var selected_recipe_id: String = ""

## Recipe button references
var recipe_buttons: Array[Button] = []

## Selected button reference
var _selected_button: Button = null

## Style for selected item
var _selected_style: StyleBoxFlat

## Cached crafter data
var _crafter: CrafterData = null

@onready var recipe_list: VBoxContainer = %RecipeList
@onready var recipe_scroll: ScrollContainer = %RecipeScroll
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var recipe_name_label: Label = %RecipeNameLabel
@onready var recipe_desc_label: Label = %RecipeDescLabel
@onready var output_label: Label = %OutputLabel
@onready var materials_label: Label = %MaterialsLabel
@onready var gold_cost_label: Label = %GoldCostLabel
@onready var craft_button: Button = %CraftButton
@onready var back_button: Button = %BackButton


func _on_initialized() -> void:
	_crafter = context.get_crafter_data()
	_create_styles()
	_populate_recipe_list()
	_update_details_panel()

	# Connect buttons
	craft_button.pressed.connect(_on_craft_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _create_styles() -> void:
	_selected_style = StyleBoxFlat.new()
	_selected_style.bg_color = Color(0.3, 0.5, 0.8, 1.0)
	_selected_style.set_corner_radius_all(2)


func _populate_recipe_list() -> void:
	# Clear existing
	for child: Node in recipe_list.get_children():
		child.queue_free()
	recipe_buttons.clear()

	# Get all recipes from registry
	var all_recipes: Array[Resource] = ModLoader.registry.get_all_resources("crafting_recipe")

	# Filter to recipes this crafter can make
	for resource: Resource in all_recipes:
		var recipe: CraftingRecipeData = resource as CraftingRecipeData
		if not recipe:
			continue

		# Check if crafter can make this recipe
		if _crafter and not _crafter.can_craft_recipe(recipe.required_crafter_type, recipe.required_crafter_skill):
			continue

		# Check story flag requirements
		var meets_flags: bool = true
		for flag: String in recipe.required_flags:
			if not GameState.has_flag(flag):
				meets_flags = false
				break
		if not meets_flags:
			continue

		var recipe_id: String = recipe.resource_path.get_file().get_basename()
		var button: Button = _create_recipe_button(recipe_id, recipe)
		recipe_list.add_child(button)
		recipe_buttons.append(button)

		button.pressed.connect(_on_recipe_selected.bind(recipe_id, button))

	# Auto-select first recipe
	if recipe_buttons.size() > 0:
		var first_id: String = recipe_buttons[0].get_meta("recipe_id")
		_select_recipe(first_id, recipe_buttons[0])
		await get_tree().process_frame
		recipe_buttons[0].grab_focus()


func _create_recipe_button(recipe_id: String, recipe: CraftingRecipeData) -> Button:
	var button: Button = Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 32)
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("recipe_id", recipe_id)

	# Check if player can afford this recipe
	var can_afford: bool = _can_afford_recipe(recipe)

	# Format button text - show recipe name and output
	var output_name: String = _get_output_display_name(recipe)
	var text: String = recipe.recipe_name
	if not output_name.is_empty() and output_name != recipe.recipe_name:
		text += " -> " + output_name

	button.text = text

	# Grey out if can't afford
	if not can_afford:
		button.add_theme_color_override("font_color", COLOR_DISABLED)

	return button


func _get_output_display_name(recipe: CraftingRecipeData) -> String:
	var output_ids: Array[String] = recipe.get_output_item_ids()
	if output_ids.is_empty():
		return ""

	if recipe.output_mode == CraftingRecipeData.OutputMode.CHOICE:
		return "(choose from %d)" % output_ids.size()

	var item_data: ItemData = get_item_data(output_ids[0])
	if item_data:
		return item_data.item_name
	return output_ids[0]


func _can_afford_recipe(recipe: CraftingRecipeData) -> bool:
	# Check gold
	var modified_cost: int = recipe.gold_cost
	if _crafter:
		modified_cost = _crafter.get_modified_cost(recipe.gold_cost)

	if get_current_gold() < modified_cost:
		return false

	# Check materials using CraftingManager if available, otherwise manual check
	if CraftingManager:
		return CraftingManager.can_craft_recipe(recipe)

	# Fallback: manual material check
	for input: Dictionary in recipe.inputs:
		var material_id: String = DictUtils.get_string(input, "material_id", "")
		var required_qty: int = DictUtils.get_int(input, "quantity", 1)
		var owned_qty: int = _count_material(material_id)
		if owned_qty < required_qty:
			return false

	return true


func _count_material(material_id: String) -> int:
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


func _on_recipe_selected(recipe_id: String, button: Button) -> void:
	_select_recipe(recipe_id, button)


func _select_recipe(recipe_id: String, button: Button) -> void:
	# Clear previous selection
	if _selected_button:
		_selected_button.remove_theme_stylebox_override("normal")

	selected_recipe_id = recipe_id
	_selected_button = button

	# Highlight new selection
	button.add_theme_stylebox_override("normal", _selected_style)

	_update_details_panel()


func _update_details_panel() -> void:
	if selected_recipe_id.is_empty():
		details_panel.hide()
		craft_button.disabled = true
		return

	var recipe: CraftingRecipeData = context.get_recipe_data(selected_recipe_id)
	if not recipe:
		details_panel.hide()
		craft_button.disabled = true
		return

	details_panel.show()

	# Recipe name
	recipe_name_label.text = recipe.recipe_name.to_upper()

	# Description
	recipe_desc_label.text = recipe.description if not recipe.description.is_empty() else ""

	# Output
	var output_text: String = "Creates: "
	match recipe.output_mode:
		CraftingRecipeData.OutputMode.SINGLE:
			var item: ItemData = get_item_data(recipe.output_item_id)
			output_text += item.item_name if item else recipe.output_item_id
		CraftingRecipeData.OutputMode.CHOICE:
			output_text += "Choose from %d items" % recipe.output_choices.size()
		CraftingRecipeData.OutputMode.UPGRADE:
			var base_item: ItemData = get_item_data(recipe.upgrade_base_item_id)
			var result_item: ItemData = get_item_data(recipe.upgrade_result_item_id)
			var base_name: String = base_item.item_name if base_item else recipe.upgrade_base_item_id
			var result_name: String = result_item.item_name if result_item else recipe.upgrade_result_item_id
			output_text += "%s -> %s" % [base_name, result_name]
	output_label.text = output_text

	# Materials
	var materials_lines: Array[String] = []
	materials_lines.append("Materials Required:")
	for input: Dictionary in recipe.inputs:
		var material_id: String = DictUtils.get_string(input, "material_id", "")
		var required_qty: int = DictUtils.get_int(input, "quantity", 1)
		var owned_qty: int = _count_material(material_id)

		var item: ItemData = get_item_data(material_id)
		var material_name: String = item.item_name if item else material_id

		var line: String = "  %s x%d" % [material_name, required_qty]
		if owned_qty < required_qty:
			line += " (have %d)" % owned_qty
		materials_lines.append(line)
	materials_label.text = "\n".join(materials_lines)

	# Update materials label color based on affordability
	var missing_any: bool = false
	for input_check: Dictionary in recipe.inputs:
		var mat_id: String = DictUtils.get_string(input_check, "material_id", "")
		var req_qty: int = DictUtils.get_int(input_check, "quantity", 1)
		if _count_material(mat_id) < req_qty:
			missing_any = true
			break

	if missing_any:
		materials_label.add_theme_color_override("font_color", COLOR_MISSING)
	else:
		materials_label.remove_theme_color_override("font_color")

	# Gold cost
	var modified_cost: int = recipe.gold_cost
	if _crafter:
		modified_cost = _crafter.get_modified_cost(recipe.gold_cost)
	gold_cost_label.text = "Cost: %dG" % modified_cost

	if get_current_gold() < modified_cost:
		gold_cost_label.add_theme_color_override("font_color", COLOR_MISSING)
	else:
		gold_cost_label.add_theme_color_override("font_color", COLOR_GOLD)

	# Update craft button
	var can_afford: bool = _can_afford_recipe(recipe)
	craft_button.disabled = not can_afford
	craft_button.text = "CRAFT - %dG" % modified_cost


func _on_craft_pressed() -> void:
	if selected_recipe_id.is_empty():
		return

	# Store selection in context and proceed to confirm
	context.selected_recipe_id = selected_recipe_id
	push_screen("crafter_confirm")


func _on_back_pressed() -> void:
	go_back()


func _on_back_requested() -> void:
	go_back()


## Clean up signal connections when exiting screen
func _on_screen_exit() -> void:
	if is_instance_valid(craft_button) and craft_button.pressed.is_connected(_on_craft_pressed):
		craft_button.pressed.disconnect(_on_craft_pressed)
	if is_instance_valid(back_button) and back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.disconnect(_on_back_pressed)

	for btn: Button in recipe_buttons:
		if not is_instance_valid(btn):
			continue
		# Disconnect any connected signals
		var connections: Array = btn.pressed.get_connections()
		for conn_entry: Dictionary in connections:
			var conn_callable: Callable = conn_entry.get("callable") as Callable
			if conn_callable and conn_callable.get_object() == self:
				btn.pressed.disconnect(conn_callable)
