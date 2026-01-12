@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Crafting Recipe Editor UI
## Allows creating and editing CraftingRecipeData resources with visual configuration
##
## Recipes define how materials are transformed into items. Three output modes:
## - SINGLE: Produces one specific item
## - CHOICE: Player chooses from multiple output options
## - UPGRADE: Enhances an existing item the player owns

# =============================================================================
# UI COMPONENTS
# =============================================================================

# Basic Info
var recipe_name_edit: LineEdit
var recipe_id_edit: LineEdit

# Output Mode
var output_mode_option: OptionButton

# Output - SINGLE mode
var single_output_section: VBoxContainer
var output_item_picker: ResourcePicker

# Output - CHOICE mode
var choice_output_section: VBoxContainer
var choice_items_list: ItemList
var choice_add_btn: Button
var choice_remove_btn: Button

# Output - UPGRADE mode
var upgrade_output_section: VBoxContainer
var upgrade_base_picker: ResourcePicker
var upgrade_result_picker: ResourcePicker

# Inputs (materials)
var inputs_section: VBoxContainer
var inputs_list: ItemList
var input_add_btn: Button
var input_remove_btn: Button
var input_edit_container: HBoxContainer
var input_quantity_spin: SpinBox

# Requirements
var gold_cost_spin: SpinBox
var crafter_type_option: OptionButton
var crafter_type_custom_edit: LineEdit
var crafter_skill_spin: SpinBox
var required_flags_edit: LineEdit

# Description
var description_edit: TextEdit
var unlock_hint_edit: LineEdit

# Item picker popup (shared for various item selections)
var item_picker_popup: PopupMenu
var _item_picker_target: String = ""  # "choice", "input", "single", "upgrade_base", "upgrade_result"

# Form state (not caches - tracks user edits)
var _current_inputs: Array[Dictionary] = []  # [{material_id: String, quantity: int}]
var _picker_items: Array[Resource] = []  # Temporary for popup selection
var _current_choices: Array[String] = []

# Common crafter types (same as crafter editor)
const CRAFTER_TYPES: Array[String] = [
	"(Custom)",
	"blacksmith",
	"enchanter",
	"alchemist",
	"jeweler",
	"tailor",
	"weaponsmith"
]

# Flag to prevent signal feedback loops during UI updates
var _updating_ui: bool = false


func _ready() -> void:
	resource_type_id = "crafting_recipe"
	resource_type_name = "Recipe"
	# Declare dependencies BEFORE super._ready() so base class can auto-subscribe
	resource_dependencies = ["item"]
	super._ready()


## Override: Create the recipe-specific detail form
func _create_detail_form() -> void:
	_add_basic_info_section()
	_add_output_mode_section()
	_add_single_output_section()
	_add_choice_output_section()
	_add_upgrade_output_section()
	_add_inputs_section()
	_add_requirements_section()
	_add_description_section()

	# Create shared item picker popup
	_create_item_picker_popup()

	# Add button container at end (with separator for visual clarity)
	_add_button_container_to_detail_panel()

	# Initial visibility update
	_update_output_section_visibility(0)


## Override: Load recipe data from resource into UI
func _load_resource_data() -> void:
	var recipe: CraftingRecipeData = current_resource as CraftingRecipeData
	if not recipe:
		return

	_updating_ui = true

	# Basic info
	recipe_id_edit.text = _get_recipe_id_from_resource()
	recipe_name_edit.text = recipe.recipe_name

	# Output mode
	output_mode_option.select(recipe.output_mode)
	_update_output_section_visibility(recipe.output_mode)

	# SINGLE output
	if not recipe.output_item_id.is_empty():
		var item_res: ItemData = ModLoader.registry.get_item(recipe.output_item_id) if ModLoader and ModLoader.registry else null
		if item_res:
			output_item_picker.select_resource(item_res)
		else:
			output_item_picker.select_none()
	else:
		output_item_picker.select_none()

	# CHOICE output
	_current_choices = recipe.output_choices.duplicate()
	_refresh_choice_list()

	# UPGRADE output
	if not recipe.upgrade_base_item_id.is_empty():
		var base_res: ItemData = ModLoader.registry.get_item(recipe.upgrade_base_item_id) if ModLoader and ModLoader.registry else null
		if base_res:
			upgrade_base_picker.select_resource(base_res)
		else:
			upgrade_base_picker.select_none()
	else:
		upgrade_base_picker.select_none()

	if not recipe.upgrade_result_item_id.is_empty():
		var result_res: ItemData = ModLoader.registry.get_item(recipe.upgrade_result_item_id) if ModLoader and ModLoader.registry else null
		if result_res:
			upgrade_result_picker.select_resource(result_res)
		else:
			upgrade_result_picker.select_none()
	else:
		upgrade_result_picker.select_none()

	# Inputs
	_current_inputs = recipe.inputs.duplicate(true)
	_refresh_inputs_list()

	# Requirements
	gold_cost_spin.value = recipe.gold_cost
	_set_crafter_type(recipe.required_crafter_type)
	crafter_skill_spin.value = recipe.required_crafter_skill
	required_flags_edit.text = ",".join(recipe.required_flags)

	# Description
	description_edit.text = recipe.description
	unlock_hint_edit.text = recipe.unlock_hint

	_updating_ui = false


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var recipe: CraftingRecipeData = current_resource as CraftingRecipeData
	if not recipe:
		return

	# Basic info
	recipe.recipe_name = recipe_name_edit.text.strip_edges()

	# Output mode
	recipe.output_mode = output_mode_option.selected as CraftingRecipeData.OutputMode

	# SINGLE output
	var single_item: Resource = output_item_picker.get_selected_resource()
	recipe.output_item_id = single_item.resource_path.get_file().get_basename() if single_item else ""

	# CHOICE output
	recipe.output_choices = _current_choices.duplicate()

	# UPGRADE output
	var base_item: Resource = upgrade_base_picker.get_selected_resource()
	recipe.upgrade_base_item_id = base_item.resource_path.get_file().get_basename() if base_item else ""

	var result_item: Resource = upgrade_result_picker.get_selected_resource()
	recipe.upgrade_result_item_id = result_item.resource_path.get_file().get_basename() if result_item else ""

	# Inputs
	recipe.inputs = _current_inputs.duplicate(true)

	# Requirements
	recipe.gold_cost = int(gold_cost_spin.value)
	recipe.required_crafter_type = _get_crafter_type()
	recipe.required_crafter_skill = int(crafter_skill_spin.value)
	recipe.required_flags = _parse_string_array(required_flags_edit.text)

	# Description
	recipe.description = description_edit.text
	recipe.unlock_hint = unlock_hint_edit.text.strip_edges()


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var recipe: CraftingRecipeData = current_resource as CraftingRecipeData
	if not recipe:
		return {valid = false, errors = ["Invalid resource type"]}

	var errors: Array[String] = []

	if recipe_name_edit.text.strip_edges().is_empty():
		errors.append("Recipe name cannot be empty")

	# Validate inputs
	if _current_inputs.is_empty():
		errors.append("Recipe must have at least one input material")
	else:
		for i: int in _current_inputs.size():
			var input: Dictionary = _current_inputs[i]
			var material_id: String = input.get("material_id", "")
			var quantity: int = input.get("quantity", 0)
			if material_id.is_empty():
				errors.append("Input %d: Material ID is missing" % (i + 1))
			elif not _item_exists(material_id):
				errors.append("Input %d: Material '%s' not found" % [(i + 1), material_id])
			if quantity < 1:
				errors.append("Input %d: Quantity must be at least 1" % (i + 1))

	# Validate output based on mode
	var output_mode: int = output_mode_option.selected
	match output_mode:
		CraftingRecipeData.OutputMode.SINGLE:
			if not output_item_picker.has_selection():
				errors.append("SINGLE mode requires an output item")
		CraftingRecipeData.OutputMode.CHOICE:
			if _current_choices.size() < 2:
				errors.append("CHOICE mode requires at least 2 output options")
			for choice_id: String in _current_choices:
				if not _item_exists(choice_id):
					errors.append("Choice item '%s' not found" % choice_id)
		CraftingRecipeData.OutputMode.UPGRADE:
			if not upgrade_base_picker.has_selection():
				errors.append("UPGRADE mode requires a base item")
			if not upgrade_result_picker.has_selection():
				errors.append("UPGRADE mode requires a result item")

	if gold_cost_spin.value < 0:
		errors.append("Gold cost cannot be negative")

	if crafter_skill_spin.value < 1:
		errors.append("Required crafter skill must be at least 1")

	return {valid = errors.is_empty(), errors = errors}


## Override: Create a new recipe with defaults
func _create_new_resource() -> Resource:
	var new_recipe: CraftingRecipeData = CraftingRecipeData.new()
	new_recipe.recipe_name = "New Recipe"
	new_recipe.output_mode = CraftingRecipeData.OutputMode.SINGLE
	new_recipe.output_item_id = ""
	# Note: output_choices defaults to empty Array[String] - don't reassign
	new_recipe.upgrade_base_item_id = ""
	new_recipe.upgrade_result_item_id = ""
	# Note: inputs defaults to empty Array[Dictionary] - don't reassign
	new_recipe.gold_cost = 100
	new_recipe.required_crafter_type = "blacksmith"
	new_recipe.required_crafter_skill = 1
	# Note: required_flags defaults to empty Array[String] - don't reassign
	new_recipe.description = ""
	new_recipe.unlock_hint = ""
	return new_recipe


## Override: Get the display name from a recipe resource
func _get_resource_display_name(resource: Resource) -> String:
	var recipe: CraftingRecipeData = resource as CraftingRecipeData
	if recipe:
		if not recipe.recipe_name.is_empty():
			return recipe.recipe_name
	return "Unnamed Recipe"


# =============================================================================
# UI CREATION HELPERS
# =============================================================================

func _add_basic_info_section() -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Basic Information", detail_panel)

	# Recipe Name
	var name_row: HBoxContainer = SparklingEditorUtils.create_field_row("Recipe Name:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	recipe_name_edit = LineEdit.new()
	recipe_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_name_edit.max_length = 64  # Reasonable limit for UI display
	recipe_name_edit.placeholder_text = "e.g., Mithril Sword Forging"
	recipe_name_edit.tooltip_text = "Display name for this recipe. Shown in crafting menus."
	recipe_name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(recipe_name_edit)

	# Recipe ID (read-only, derived from filename)
	var id_row: HBoxContainer = SparklingEditorUtils.create_field_row("Recipe ID:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	recipe_id_edit = LineEdit.new()
	recipe_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_id_edit.placeholder_text = "(from filename)"
	recipe_id_edit.tooltip_text = "Unique ID derived from filename. Rename file to change ID."
	recipe_id_edit.editable = false
	id_row.add_child(recipe_id_edit)


func _add_output_mode_section() -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Output Mode", detail_panel)

	var mode_row: HBoxContainer = SparklingEditorUtils.create_field_row("Mode:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	output_mode_option = OptionButton.new()
	output_mode_option.tooltip_text = "How this recipe produces output. SINGLE = one item. CHOICE = player picks. UPGRADE = transforms existing item."
	output_mode_option.add_item("Single Item", CraftingRecipeData.OutputMode.SINGLE)
	output_mode_option.add_item("Player Choice", CraftingRecipeData.OutputMode.CHOICE)
	output_mode_option.add_item("Item Upgrade", CraftingRecipeData.OutputMode.UPGRADE)
	output_mode_option.item_selected.connect(_on_output_mode_changed)
	mode_row.add_child(output_mode_option)

	SparklingEditorUtils.create_help_label("SINGLE: One specific output. CHOICE: Player picks from options. UPGRADE: Enhance existing item.", section)


func _add_single_output_section() -> void:
	single_output_section = SparklingEditorUtils.create_section("Output Item", detail_panel)

	output_item_picker = ResourcePicker.new()
	output_item_picker.resource_type = "item"
	output_item_picker.label_text = "Output Item:"
	output_item_picker.label_min_width = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	output_item_picker.allow_none = false
	output_item_picker.tooltip_text = "The item produced by this recipe."
	output_item_picker.resource_selected.connect(_on_output_item_selected)
	single_output_section.add_child(output_item_picker)


func _add_choice_output_section() -> void:
	choice_output_section = SparklingEditorUtils.create_section("Output Choices", detail_panel)

	SparklingEditorUtils.create_help_label("Player chooses one of these items when crafting", choice_output_section)

	choice_items_list = ItemList.new()
	choice_items_list.custom_minimum_size = Vector2(0, 100)
	choice_output_section.add_child(choice_items_list)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)

	choice_add_btn = Button.new()
	choice_add_btn.text = "Add Choice..."
	choice_add_btn.tooltip_text = "Add an item to the output choices"
	choice_add_btn.pressed.connect(_on_add_choice)
	btn_row.add_child(choice_add_btn)

	choice_remove_btn = Button.new()
	choice_remove_btn.text = "Remove Selected"
	choice_remove_btn.tooltip_text = "Remove the selected choice"
	choice_remove_btn.pressed.connect(_on_remove_choice)
	btn_row.add_child(choice_remove_btn)

	choice_output_section.add_child(btn_row)


func _add_upgrade_output_section() -> void:
	upgrade_output_section = SparklingEditorUtils.create_section("Upgrade Configuration", detail_panel)

	SparklingEditorUtils.create_help_label("Player must own the base item. It transforms into the result.", upgrade_output_section)

	upgrade_base_picker = ResourcePicker.new()
	upgrade_base_picker.resource_type = "item"
	upgrade_base_picker.label_text = "Base Item:"
	upgrade_base_picker.label_min_width = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	upgrade_base_picker.allow_none = false
	upgrade_base_picker.tooltip_text = "The item being upgraded. Player must own this."
	upgrade_base_picker.resource_selected.connect(_on_upgrade_base_selected)
	upgrade_output_section.add_child(upgrade_base_picker)

	upgrade_result_picker = ResourcePicker.new()
	upgrade_result_picker.resource_type = "item"
	upgrade_result_picker.label_text = "Result Item:"
	upgrade_result_picker.label_min_width = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	upgrade_result_picker.allow_none = false
	upgrade_result_picker.tooltip_text = "What the base item becomes after upgrading."
	upgrade_result_picker.resource_selected.connect(_on_upgrade_result_selected)
	upgrade_output_section.add_child(upgrade_result_picker)


func _add_inputs_section() -> void:
	inputs_section = SparklingEditorUtils.create_section("Required Materials", detail_panel)

	SparklingEditorUtils.create_help_label("Materials consumed when crafting this recipe", inputs_section)

	inputs_list = ItemList.new()
	inputs_list.custom_minimum_size = Vector2(0, 120)
	inputs_list.item_selected.connect(_on_input_selected)
	inputs_section.add_child(inputs_list)

	# Edit controls for selected input
	input_edit_container = HBoxContainer.new()
	input_edit_container.add_theme_constant_override("separation", 8)
	input_edit_container.visible = false

	var qty_label: Label = Label.new()
	qty_label.text = "Quantity:"
	input_edit_container.add_child(qty_label)

	input_quantity_spin = SpinBox.new()
	input_quantity_spin.min_value = 1
	input_quantity_spin.max_value = 999
	input_quantity_spin.value = 1
	input_quantity_spin.tooltip_text = "How many of this material are required"
	input_quantity_spin.value_changed.connect(_on_input_quantity_changed)
	input_edit_container.add_child(input_quantity_spin)

	inputs_section.add_child(input_edit_container)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)

	input_add_btn = Button.new()
	input_add_btn.text = "Add Material..."
	input_add_btn.tooltip_text = "Add a material requirement"
	input_add_btn.pressed.connect(_on_add_input)
	btn_row.add_child(input_add_btn)

	input_remove_btn = Button.new()
	input_remove_btn.text = "Remove Selected"
	input_remove_btn.tooltip_text = "Remove the selected material"
	input_remove_btn.pressed.connect(_on_remove_input)
	btn_row.add_child(input_remove_btn)

	inputs_section.add_child(btn_row)


func _add_requirements_section() -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Requirements", detail_panel)

	# Gold cost
	var gold_row: HBoxContainer = SparklingEditorUtils.create_field_row("Gold Cost:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	gold_cost_spin = SpinBox.new()
	gold_cost_spin.min_value = 0
	gold_cost_spin.max_value = 999999
	gold_cost_spin.value = 100
	gold_cost_spin.tooltip_text = "Gold paid to craft this recipe. Modified by crafter's service fee."
	gold_cost_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	gold_row.add_child(gold_cost_spin)

	# Crafter type
	var type_row: HBoxContainer = SparklingEditorUtils.create_field_row("Crafter Type:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	crafter_type_option = OptionButton.new()
	crafter_type_option.tooltip_text = "Type of crafter required. Must match crafter's type exactly."
	for crafter_type: String in CRAFTER_TYPES:
		crafter_type_option.add_item(crafter_type)
	crafter_type_option.item_selected.connect(_on_crafter_type_selected)
	type_row.add_child(crafter_type_option)

	crafter_type_custom_edit = LineEdit.new()
	crafter_type_custom_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crafter_type_custom_edit.placeholder_text = "custom_type"
	crafter_type_custom_edit.tooltip_text = "Enter a custom crafter type."
	crafter_type_custom_edit.visible = false
	crafter_type_custom_edit.text_changed.connect(_mark_dirty)
	type_row.add_child(crafter_type_custom_edit)

	# Crafter skill
	var skill_row: HBoxContainer = SparklingEditorUtils.create_field_row("Min. Skill Level:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	crafter_skill_spin = SpinBox.new()
	crafter_skill_spin.min_value = 1
	crafter_skill_spin.max_value = 99
	crafter_skill_spin.value = 1
	crafter_skill_spin.tooltip_text = "Minimum crafter skill level required. Higher = more exclusive."
	crafter_skill_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	skill_row.add_child(crafter_skill_spin)

	# Required flags
	var flags_row: HBoxContainer = SparklingEditorUtils.create_field_row("Required Flags:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	required_flags_edit = LineEdit.new()
	required_flags_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	required_flags_edit.placeholder_text = "e.g., found_ancient_anvil, learned_enchanting"
	required_flags_edit.tooltip_text = "Comma-separated story flags. ALL must be set for recipe to be available."
	required_flags_edit.text_changed.connect(_mark_dirty)
	flags_row.add_child(required_flags_edit)

	SparklingEditorUtils.create_help_label("Recipe only shown if player meets all requirements", section)


func _add_description_section() -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Description", detail_panel)

	var desc_label: Label = Label.new()
	desc_label.text = "Description:"
	section.add_child(desc_label)

	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 60
	description_edit.placeholder_text = "Forge a legendary sword from mithril ore..."
	description_edit.tooltip_text = "Flavor text describing this recipe. Shown in crafting menus."
	description_edit.text_changed.connect(_mark_dirty)
	section.add_child(description_edit)

	# Unlock hint
	var hint_row: HBoxContainer = SparklingEditorUtils.create_field_row("Unlock Hint:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	unlock_hint_edit = LineEdit.new()
	unlock_hint_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlock_hint_edit.placeholder_text = "e.g., Find the ancient forge"
	unlock_hint_edit.tooltip_text = "Hint shown when recipe is locked. Helps players discover how to unlock."
	unlock_hint_edit.text_changed.connect(_mark_dirty)
	hint_row.add_child(unlock_hint_edit)

	SparklingEditorUtils.create_help_label("Unlock hint shown if player doesn't meet requirements", section)


func _create_item_picker_popup() -> void:
	item_picker_popup = PopupMenu.new()
	item_picker_popup.id_pressed.connect(_on_item_picker_selected)
	add_child(item_picker_popup)


# =============================================================================
# EVENT HANDLERS
# =============================================================================

func _on_name_changed(_new_text: String) -> void:
	if _updating_ui:
		return
	_mark_dirty()


func _on_output_mode_changed(index: int) -> void:
	if _updating_ui:
		return
	_update_output_section_visibility(index)
	_mark_dirty()


func _update_output_section_visibility(mode: int) -> void:
	single_output_section.visible = (mode == CraftingRecipeData.OutputMode.SINGLE)
	choice_output_section.visible = (mode == CraftingRecipeData.OutputMode.CHOICE)
	upgrade_output_section.visible = (mode == CraftingRecipeData.OutputMode.UPGRADE)


func _on_output_item_selected(_metadata: Dictionary) -> void:
	if _updating_ui:
		return
	_mark_dirty()


func _on_upgrade_base_selected(_metadata: Dictionary) -> void:
	if _updating_ui:
		return
	_mark_dirty()


func _on_upgrade_result_selected(_metadata: Dictionary) -> void:
	if _updating_ui:
		return
	_mark_dirty()


func _on_add_choice() -> void:
	_item_picker_target = "choice"
	_show_item_picker()


func _on_remove_choice() -> void:
	var selected: PackedInt32Array = choice_items_list.get_selected_items()
	if selected.is_empty():
		return

	var index: int = selected[0]
	if index >= 0 and index < _current_choices.size():
		_current_choices.remove_at(index)
		_refresh_choice_list()
		_mark_dirty()


func _on_add_input() -> void:
	_item_picker_target = "input"
	_show_item_picker()


func _on_remove_input() -> void:
	var selected: PackedInt32Array = inputs_list.get_selected_items()
	if selected.is_empty():
		return

	var index: int = selected[0]
	if index >= 0 and index < _current_inputs.size():
		_current_inputs.remove_at(index)
		_refresh_inputs_list()
		input_edit_container.visible = false
		_mark_dirty()


func _on_input_selected(index: int) -> void:
	if index < 0 or index >= _current_inputs.size():
		input_edit_container.visible = false
		return

	input_edit_container.visible = true
	var input_entry: Dictionary = _current_inputs[index]
	input_quantity_spin.value = input_entry.get("quantity", 1)


func _on_input_quantity_changed(value: float) -> void:
	var selected: PackedInt32Array = inputs_list.get_selected_items()
	if selected.is_empty():
		return

	var index: int = selected[0]
	if index >= 0 and index < _current_inputs.size():
		_current_inputs[index]["quantity"] = int(value)
		_refresh_inputs_list()
		inputs_list.select(index)
		_mark_dirty()


func _on_crafter_type_selected(index: int) -> void:
	if _updating_ui:
		return
	crafter_type_custom_edit.visible = (index == 0)  # "(Custom)" is index 0
	_mark_dirty()


func _show_item_picker() -> void:
	item_picker_popup.clear()
	_picker_items.clear()

	# Query registry fresh each time
	if ModLoader and ModLoader.registry:
		_picker_items = ModLoader.registry.get_all_resources("item")

	for i: int in _picker_items.size():
		var item: ItemData = _picker_items[i] as ItemData
		if item:
			var label: String = "%s" % item.item_name
			item_picker_popup.add_item(label, i)

	if item_picker_popup.item_count == 0:
		item_picker_popup.add_item("(No items available)", -1)
		item_picker_popup.set_item_disabled(0, true)

	item_picker_popup.popup_centered()


func _on_item_picker_selected(id: int) -> void:
	if id < 0 or id >= _picker_items.size():
		return

	var item: ItemData = _picker_items[id] as ItemData
	if not item:
		return

	var item_id: String = item.resource_path.get_file().get_basename()
	if item_id.is_empty():
		return

	match _item_picker_target:
		"choice":
			if item_id not in _current_choices:
				_current_choices.append(item_id)
				_refresh_choice_list()
				_mark_dirty()
		"input":
			# Check if already in inputs
			for input_entry: Dictionary in _current_inputs:
				if input_entry.get("material_id", "") == item_id:
					return  # Already exists

			_current_inputs.append({
				"material_id": item_id,
				"quantity": 1
			})
			_refresh_inputs_list()
			_mark_dirty()


# =============================================================================
# HELPERS
# =============================================================================

func _get_recipe_id_from_resource() -> String:
	if current_resource and not current_resource.resource_path.is_empty():
		return current_resource.resource_path.get_file().get_basename()
	return ""


func _get_crafter_type() -> String:
	var index: int = crafter_type_option.selected
	if index == 0:  # "(Custom)"
		return crafter_type_custom_edit.text.strip_edges()
	elif index > 0 and index < CRAFTER_TYPES.size():
		return CRAFTER_TYPES[index]
	return ""


func _set_crafter_type(crafter_type: String) -> void:
	var type_index: int = CRAFTER_TYPES.find(crafter_type)
	if type_index > 0:  # Found and not "(Custom)"
		crafter_type_option.select(type_index)
		crafter_type_custom_edit.visible = false
		crafter_type_custom_edit.text = ""
	else:
		crafter_type_option.select(0)  # "(Custom)"
		crafter_type_custom_edit.visible = true
		crafter_type_custom_edit.text = crafter_type


func _parse_string_array(text: String) -> Array[String]:
	var result: Array[String] = []
	var parts: PackedStringArray = text.split(",")
	for part: String in parts:
		var trimmed: String = part.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result




func _refresh_choice_list() -> void:
	choice_items_list.clear()
	for item_id: String in _current_choices:
		var item_name: String = _get_item_name(item_id)
		choice_items_list.add_item(item_name)


func _refresh_inputs_list() -> void:
	inputs_list.clear()
	for input_entry: Dictionary in _current_inputs:
		var material_id: String = input_entry.get("material_id", "")
		var quantity: int = input_entry.get("quantity", 1)
		var material_name: String = _get_item_name(material_id)
		var label: String = "%s x%d" % [material_name, quantity]
		inputs_list.add_item(label)


func _get_item_name(item_id: String) -> String:
	# Query registry directly
	if ModLoader and ModLoader.registry:
		var item: ItemData = ModLoader.registry.get_item(item_id)
		if item:
			return item.item_name
	return item_id  # Fallback to ID


func _item_exists(item_id: String) -> bool:
	# Query registry directly
	if ModLoader and ModLoader.registry:
		return ModLoader.registry.has_resource("item", item_id)
	return false


## Override: Called when dependent resource types change (via base class)
func _on_dependencies_changed(_changed_type: String) -> void:
	# Refresh pickers (they query registry directly)
	if output_item_picker:
		output_item_picker.refresh()
	if upgrade_base_picker:
		upgrade_base_picker.refresh()
	if upgrade_result_picker:
		upgrade_result_picker.refresh()

	# Re-validate and update display for current resource
	# This catches stale references to deleted items
	if current_resource:
		_refresh_inputs_list()
		_refresh_choice_list()
		var validation: Dictionary = _validate_resource()
		if not validation.valid:
			_show_errors(validation.errors)


## Override refresh to also refresh pickers
func refresh() -> void:
	if output_item_picker:
		output_item_picker.refresh()
	if upgrade_base_picker:
		upgrade_base_picker.refresh()
	if upgrade_result_picker:
		upgrade_result_picker.refresh()
	super.refresh()
