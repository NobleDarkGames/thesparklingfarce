@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Interactable Editor UI
## Allows browsing and editing InteractableData resources (chests, bookshelves, barrels, etc.)
##
## Interactables are single-tile objects on maps that respond to player interaction.
## They can:
## - Grant items and gold (chests, barrels)
## - Display messages (signs, bookshelves)
## - Trigger cinematics (levers, special objects)
## - Track opened/used state via GameState flags
##
## User-Friendly Design:
## - Template presets for common types (chest, bookshelf, etc.)
## - Visual sprite preview for closed/opened states
## - Item reward list with quantity editing
## - Simple dialog text field for basic messages
## - Advanced cinematic options hidden by default

# =============================================================================
# UI FIELD REFERENCES - Basic Information
# =============================================================================

var name_id_group: NameIdFieldGroup
var type_option: OptionButton
var template_option: OptionButton

# =============================================================================
# TEMPLATES - Preset configurations for common interactable types
# =============================================================================

const INTERACTABLE_TEMPLATES: Dictionary = {
	"custom": {
		"label": "Custom",
		"type": InteractableData.InteractableType.CUSTOM,
		"name": "",
		"one_shot": true,
		"dialog": ""
	},
	"treasure_chest": {
		"label": "Treasure Chest",
		"type": InteractableData.InteractableType.CHEST,
		"name": "Treasure Chest",
		"one_shot": true,
		"dialog": ""
	},
	"wooden_chest": {
		"label": "Wooden Chest",
		"type": InteractableData.InteractableType.CHEST,
		"name": "Wooden Chest",
		"one_shot": true,
		"dialog": ""
	},
	"bookshelf": {
		"label": "Bookshelf",
		"type": InteractableData.InteractableType.BOOKSHELF,
		"name": "Bookshelf",
		"one_shot": false,
		"dialog": "The bookshelf is filled with dusty tomes.\nNothing of interest catches your eye."
	},
	"sign_post": {
		"label": "Sign Post",
		"type": InteractableData.InteractableType.SIGN,
		"name": "Sign",
		"one_shot": false,
		"dialog": "Welcome to our village!"
	},
	"barrel": {
		"label": "Barrel",
		"type": InteractableData.InteractableType.BARREL,
		"name": "Barrel",
		"one_shot": true,
		"dialog": ""
	},
	"lever": {
		"label": "Lever",
		"type": InteractableData.InteractableType.LEVER,
		"name": "Lever",
		"one_shot": false,
		"dialog": ""
	}
}

# =============================================================================
# UI FIELD REFERENCES - Appearance
# =============================================================================

var appearance_section: VBoxContainer
var sprite_closed_preview: TextureRect
var sprite_closed_path_edit: LineEdit
var sprite_opened_preview: TextureRect
var sprite_opened_path_edit: LineEdit
var sprite_file_dialog: EditorFileDialog
var _current_sprite_target: String = ""  # "closed" or "opened"

# =============================================================================
# UI FIELD REFERENCES - Rewards
# =============================================================================

var rewards_section: VBoxContainer
var gold_reward_spin: SpinBox

# DynamicRowList for item rewards
var item_rewards_list: DynamicRowList

# =============================================================================
# UI FIELD REFERENCES - Interaction
# =============================================================================

var advanced_section: VBoxContainer
var advanced_toggle_btn: Button
var advanced_content: VBoxContainer

# Cinematic pickers - using ResourcePicker for mod-aware selection
var interaction_cinematic_picker: ResourcePicker
var interaction_warning_label: Label
var fallback_cinematic_picker: ResourcePicker
var fallback_warning_label: Label

# =============================================================================
# UI FIELD REFERENCES - Conditional Cinematics
# =============================================================================

# DynamicRowList for conditional cinematics
var conditionals_list: DynamicRowList

# =============================================================================
# UI FIELD REFERENCES - Behavior
# =============================================================================

var one_shot_check: CheckBox
var required_flags_edit: LineEdit
var forbidden_flags_edit: LineEdit
var completion_flag_edit: LineEdit

# =============================================================================
# UI FIELD REFERENCES - Place on Map
# =============================================================================

var place_on_map_btn: Button
var place_position_x: SpinBox
var place_position_y: SpinBox
var place_on_map_dialog: PlaceOnMapDialog
var map_placement_helper: MapPlacementHelper

# =============================================================================
# STATE TRACKING
# =============================================================================


func _ready() -> void:
	resource_type_name = "Interactable"
	resource_type_id = "interactable"
	# Depend on items for the reward picker
	resource_dependencies = ["item"]
	super._ready()

	# Initialize helper components
	map_placement_helper = MapPlacementHelper.new()

	# Connect to EditorEventBus for refresh notifications
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	if event_bus and not event_bus.mods_reloaded.is_connected(_on_mods_reloaded):
		event_bus.mods_reloaded.connect(_on_mods_reloaded)


func _exit_tree() -> void:
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	if event_bus and event_bus.mods_reloaded.is_connected(_on_mods_reloaded):
		event_bus.mods_reloaded.disconnect(_on_mods_reloaded)


func _on_mods_reloaded() -> void:
	_refresh_list()


func _on_dependencies_changed(_changed_type: String) -> void:
	# Refresh item pickers when items change
	_refresh_item_reward_pickers()


# =============================================================================
# DETAIL FORM CREATION
# =============================================================================

## Override: Create the Interactable-specific detail form
func _create_detail_form() -> void:
	_add_basic_info_section()
	_add_appearance_section()
	_add_rewards_section()
	_add_place_on_map_section()
	_add_advanced_options_section()

	# Add the button container at the end (with separator for visual clarity)
	_add_button_container_to_detail_panel()


func _add_basic_info_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Basic Information")

	# Template selector
	template_option = OptionButton.new()
	var idx: int = 0
	for key: String in INTERACTABLE_TEMPLATES.keys():
		var template: Dictionary = INTERACTABLE_TEMPLATES[key]
		var template_label: String = template.get("label", key)
		template_option.add_item(template_label, idx)
		template_option.set_item_metadata(idx, key)
		idx += 1
	template_option.item_selected.connect(_on_template_selected)
	form.add_labeled_control("Start from:", template_option)

	form.add_help_text("Choose a template to pre-fill common interactable types")

	# Name/ID using reusable component
	name_id_group = NameIdFieldGroup.new()
	name_id_group.name_label = "Display Name:"
	name_id_group.id_label = "Interactable ID:"
	name_id_group.name_placeholder = "Treasure Chest, Dusty Bookshelf..."
	name_id_group.id_placeholder = "(auto-generated from name)"
	name_id_group.name_tooltip = "Name shown in messages and UI. E.g., 'Treasure Chest', 'Old Sign'."
	name_id_group.id_tooltip = "Unique ID for referencing this interactable. Auto-generates from name."
	name_id_group.label_width = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	name_id_group.value_changed.connect(_on_name_id_changed)
	form.container.add_child(name_id_group)

	# Interactable Type
	type_option = OptionButton.new()
	type_option.tooltip_text = "Determines default behavior and editor suggestions."
	type_option.add_item("Chest", InteractableData.InteractableType.CHEST)
	type_option.add_item("Bookshelf", InteractableData.InteractableType.BOOKSHELF)
	type_option.add_item("Barrel", InteractableData.InteractableType.BARREL)
	type_option.add_item("Sign", InteractableData.InteractableType.SIGN)
	type_option.add_item("Lever", InteractableData.InteractableType.LEVER)
	type_option.add_item("Custom", InteractableData.InteractableType.CUSTOM)
	type_option.item_selected.connect(_on_type_changed)
	form.add_labeled_control("Type:", type_option)

	form.add_help_text("Chest/Barrel = one-shot items. Bookshelf/Sign = repeatable text. Lever = state toggle.")


func _add_appearance_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Appearance")
	appearance_section = form.container as VBoxContainer

	# Sprite Closed row
	var closed_row: HBoxContainer = HBoxContainer.new()
	closed_row.add_theme_constant_override("separation", 8)

	var closed_label: Label = Label.new()
	closed_label.text = "Sprite (Closed):"
	closed_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	closed_row.add_child(closed_label)

	var closed_preview_panel: PanelContainer = _create_sprite_preview_panel()
	var closed_child: Node = closed_preview_panel.get_child(0)
	sprite_closed_preview = closed_child if closed_child is TextureRect else null
	closed_row.add_child(closed_preview_panel)

	sprite_closed_path_edit = LineEdit.new()
	sprite_closed_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_closed_path_edit.placeholder_text = "res://mods/.../assets/sprites/chest_closed.png"
	sprite_closed_path_edit.tooltip_text = "Sprite shown when interactable is in closed/unsearched state"
	sprite_closed_path_edit.text_changed.connect(_on_sprite_closed_path_changed)
	closed_row.add_child(sprite_closed_path_edit)

	var closed_browse_btn: Button = Button.new()
	closed_browse_btn.text = "Browse..."
	closed_browse_btn.pressed.connect(_on_browse_sprite_closed)
	closed_row.add_child(closed_browse_btn)

	var closed_clear_btn: Button = Button.new()
	closed_clear_btn.text = "X"
	closed_clear_btn.tooltip_text = "Clear sprite"
	closed_clear_btn.pressed.connect(_on_clear_sprite_closed)
	closed_row.add_child(closed_clear_btn)

	form.container.add_child(closed_row)

	# Sprite Opened row
	var opened_row: HBoxContainer = HBoxContainer.new()
	opened_row.add_theme_constant_override("separation", 8)

	var opened_label: Label = Label.new()
	opened_label.text = "Sprite (Opened):"
	opened_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	opened_row.add_child(opened_label)

	var opened_preview_panel: PanelContainer = _create_sprite_preview_panel()
	var opened_child: Node = opened_preview_panel.get_child(0)
	sprite_opened_preview = opened_child if opened_child is TextureRect else null
	opened_row.add_child(opened_preview_panel)

	sprite_opened_path_edit = LineEdit.new()
	sprite_opened_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_opened_path_edit.placeholder_text = "(optional - uses closed sprite if empty)"
	sprite_opened_path_edit.tooltip_text = "Sprite shown after searching/opening. Leave empty to use closed sprite."
	sprite_opened_path_edit.text_changed.connect(_on_sprite_opened_path_changed)
	opened_row.add_child(sprite_opened_path_edit)

	var opened_browse_btn: Button = Button.new()
	opened_browse_btn.text = "Browse..."
	opened_browse_btn.pressed.connect(_on_browse_sprite_opened)
	opened_row.add_child(opened_browse_btn)

	var opened_clear_btn: Button = Button.new()
	opened_clear_btn.text = "X"
	opened_clear_btn.tooltip_text = "Clear sprite"
	opened_clear_btn.pressed.connect(_on_clear_sprite_opened)
	opened_row.add_child(opened_clear_btn)

	form.container.add_child(opened_row)

	form.add_help_text("32x32 sprites recommended. Opened sprite is optional (one-shot items stay opened).")


func _create_sprite_preview_panel() -> PanelContainer:
	var preview_panel: PanelContainer = PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(36, 36)
	var preview_style: StyleBoxFlat = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	preview_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	preview_style.set_border_width_all(1)
	preview_style.set_content_margin_all(2)
	preview_panel.add_theme_stylebox_override("panel", preview_style)

	var preview_rect: TextureRect = TextureRect.new()
	preview_rect.custom_minimum_size = Vector2(32, 32)
	preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_panel.add_child(preview_rect)

	return preview_panel


func _add_rewards_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Rewards")
	rewards_section = form.container as VBoxContainer

	form.add_help_text("Items and gold granted when this interactable is searched. Best for chests/barrels.")

	# Gold reward
	gold_reward_spin = form.add_number_field("Gold:", 0, 999999, 0,
		"Amount of gold to grant when searched")

	# Item rewards label
	var items_label: Label = Label.new()
	items_label.text = "Item Rewards:"
	form.container.add_child(items_label)

	# Use DynamicRowList for item rewards
	item_rewards_list = DynamicRowList.new()
	item_rewards_list.add_button_text = "+ Add Item"
	item_rewards_list.add_button_tooltip = "Add an item reward to this interactable"
	item_rewards_list.row_factory = _create_item_reward_row
	item_rewards_list.data_extractor = _extract_item_reward_data
	item_rewards_list.data_changed.connect(_on_item_reward_data_changed)
	form.container.add_child(item_rewards_list)


func _add_place_on_map_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Place on Map")

	# Grid position row - custom layout for X/Y spinboxes
	var pos_row: HBoxContainer = HBoxContainer.new()
	pos_row.add_theme_constant_override("separation", 8)

	var pos_label: Label = Label.new()
	pos_label.text = "Grid Position:"
	pos_label.custom_minimum_size.x = 100
	pos_row.add_child(pos_label)

	var x_label: Label = Label.new()
	x_label.text = "X:"
	pos_row.add_child(x_label)

	place_position_x = SpinBox.new()
	place_position_x.min_value = -100
	place_position_x.max_value = 100
	place_position_x.value = 5
	place_position_x.custom_minimum_size.x = 70
	place_position_x.tooltip_text = "X grid coordinate where interactable will be placed on the map."
	pos_row.add_child(place_position_x)

	var y_label: Label = Label.new()
	y_label.text = "Y:"
	pos_row.add_child(y_label)

	place_position_y = SpinBox.new()
	place_position_y.min_value = -100
	place_position_y.max_value = 100
	place_position_y.value = 5
	place_position_y.custom_minimum_size.x = 70
	place_position_y.tooltip_text = "Y grid coordinate where interactable will be placed on the map."
	pos_row.add_child(place_position_y)

	form.container.add_child(pos_row)

	place_on_map_btn = Button.new()
	place_on_map_btn.text = "Place on Map..."
	place_on_map_btn.tooltip_text = "Add this interactable to a map in the current mod"
	place_on_map_btn.pressed.connect(_on_place_on_map_pressed)
	form.container.add_child(place_on_map_btn)

	form.add_help_text("Save the interactable first, then click to add it to a map")

	# Create the map selection dialog component
	place_on_map_dialog = PlaceOnMapDialog.new()
	place_on_map_dialog.setup(self, "Interactable")
	place_on_map_dialog.map_confirmed.connect(_on_map_selection_confirmed)
	place_on_map_dialog.error_occurred.connect(_show_error)


func _add_advanced_options_section() -> void:
	advanced_section = VBoxContainer.new()

	advanced_toggle_btn = Button.new()
	advanced_toggle_btn.text = "Advanced Options"
	advanced_toggle_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	advanced_toggle_btn.flat = true
	advanced_toggle_btn.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	advanced_toggle_btn.pressed.connect(_on_advanced_toggle)
	advanced_section.add_child(advanced_toggle_btn)

	advanced_content = VBoxContainer.new()
	advanced_content.visible = false
	advanced_section.add_child(advanced_content)

	_add_cinematic_section_to(advanced_content)
	_add_conditional_cinematics_section_to(advanced_content)
	_add_behavior_section_to(advanced_content)

	detail_panel.add_child(advanced_section)


func _add_cinematic_section_to(parent: Control) -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(parent)
	form.on_change(_mark_dirty)
	form.add_section("Cinematic Assignment")

	# Primary cinematic picker
	interaction_cinematic_picker = ResourcePicker.new()
	interaction_cinematic_picker.resource_type = "cinematic"
	interaction_cinematic_picker.allow_none = true
	interaction_cinematic_picker.none_text = "(None)"
	interaction_cinematic_picker.tooltip_text = "Explicit cinematic to play. Use for signs/bookshelves with text, or complex interactions."
	interaction_cinematic_picker.resource_selected.connect(_on_cinematic_picker_changed.bind("primary"))
	form.add_labeled_control("Interaction Cinematic:", interaction_cinematic_picker)

	interaction_warning_label = Label.new()
	interaction_warning_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	interaction_warning_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	interaction_warning_label.visible = false
	form.container.add_child(interaction_warning_label)

	form.add_help_text("Leave empty to auto-generate 'Found X!' from rewards. Use for text/complex interactions.")

	# Fallback cinematic picker
	fallback_cinematic_picker = ResourcePicker.new()
	fallback_cinematic_picker.resource_type = "cinematic"
	fallback_cinematic_picker.allow_none = true
	fallback_cinematic_picker.none_text = "(None)"
	fallback_cinematic_picker.tooltip_text = "Cinematic to play if no conditions match and no primary cinematic set."
	fallback_cinematic_picker.resource_selected.connect(_on_cinematic_picker_changed.bind("fallback"))
	form.add_labeled_control("Fallback Cinematic:", fallback_cinematic_picker)

	fallback_warning_label = Label.new()
	fallback_warning_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	fallback_warning_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	fallback_warning_label.visible = false
	form.container.add_child(fallback_warning_label)


func _add_conditional_cinematics_section_to(parent: Control) -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(parent)
	form.on_change(_mark_dirty)
	form.add_section("Conditional Cinematics")

	form.add_help_text("Conditions checked in order. First matching condition's cinematic plays.")

	# Use DynamicRowList for conditional cinematics with shared factory component
	conditionals_list = DynamicRowList.new()
	conditionals_list.add_button_text = "+ Add Condition"
	conditionals_list.add_button_tooltip = "Add a new conditional cinematic that triggers based on game flags."
	conditionals_list.use_scroll_container = true
	conditionals_list.scroll_min_height = 120
	conditionals_list.row_factory = ConditionalCinematicsRowFactory.create_row
	conditionals_list.data_extractor = ConditionalCinematicsRowFactory.extract_data
	conditionals_list.data_changed.connect(_on_conditional_data_changed)
	form.container.add_child(conditionals_list)


func _add_behavior_section_to(parent: Control) -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(parent)
	form.on_change(_mark_dirty)
	form.add_section("Behavior")

	# One Shot - standalone checkbox
	one_shot_check = form.add_standalone_checkbox("One-Shot (can only be searched once)", true,
		"If checked, this interactable can only be used once and will be marked as opened.")

	form.add_help_text("One-shot: chests, barrels (grant items once). Repeatable: signs, bookshelves (read multiple times).")

	# Required Flags
	required_flags_edit = form.add_text_field("Required Flags:", "flag1, flag2 (comma-separated)",
		"All these flags must be set for the player to interact. Leave empty for always available.")

	# Forbidden Flags
	forbidden_flags_edit = form.add_text_field("Forbidden Flags:", "flag1, flag2 (comma-separated)",
		"If ANY of these flags are set, interaction is blocked.")

	# Completion Flag
	completion_flag_edit = form.add_text_field("Completion Flag:", "(auto: {interactable_id}_opened)",
		"Flag set after successful interaction. Auto-generated if empty.")

	form.add_help_text("Completion flag tracks opened state. Leave empty for auto-generated '{id}_opened'.")


# =============================================================================
# DATA LOADING
# =============================================================================

## Override: Load interactable data from resource into UI
func _load_resource_data() -> void:
	if not current_resource is InteractableData:
		return
	var interactable: InteractableData = current_resource

	_updating_ui = true

	# Reset template to custom
	if template_option:
		template_option.select(0)

	# Basic info - load name/ID using component (auto-detects lock state)
	name_id_group.set_values(interactable.display_name, interactable.interactable_id, true)

	type_option.select(int(interactable.interactable_type))

	# Appearance
	var closed_path: String = interactable.sprite_closed.resource_path if interactable.sprite_closed else ""
	sprite_closed_path_edit.text = closed_path
	_load_sprite_preview(sprite_closed_preview, closed_path)

	var opened_path: String = interactable.sprite_opened.resource_path if interactable.sprite_opened else ""
	sprite_opened_path_edit.text = opened_path
	_load_sprite_preview(sprite_opened_preview, opened_path)

	# Rewards
	gold_reward_spin.value = interactable.gold_reward
	_load_item_rewards(interactable.item_rewards)

	# Interaction (cinematics via ResourcePicker)
	if interaction_cinematic_picker:
		if interactable.interaction_cinematic_id.is_empty():
			interaction_cinematic_picker.call_deferred("select_none")
		else:
			interaction_cinematic_picker.call_deferred("select_by_id", "", interactable.interaction_cinematic_id)
	if fallback_cinematic_picker:
		if interactable.fallback_cinematic_id.is_empty():
			fallback_cinematic_picker.call_deferred("select_none")
		else:
			fallback_cinematic_picker.call_deferred("select_by_id", "", interactable.fallback_cinematic_id)
	_load_conditional_cinematics(interactable.conditional_cinematics)

	# Behavior
	one_shot_check.button_pressed = interactable.one_shot
	required_flags_edit.text = ", ".join(interactable.required_flags)
	forbidden_flags_edit.text = ", ".join(interactable.forbidden_flags)
	completion_flag_edit.text = interactable.completion_flag

	_updating_ui = false


## Override: Save UI data to resource
func _save_resource_data() -> void:
	if not current_resource is InteractableData:
		return
	var interactable: InteractableData = current_resource

	# Basic info
	interactable.interactable_id = name_id_group.get_id_value()
	interactable.display_name = name_id_group.get_name_value()
	interactable.interactable_type = type_option.selected as InteractableData.InteractableType

	# Appearance
	var closed_path: String = sprite_closed_path_edit.text.strip_edges()
	interactable.sprite_closed = SparklingEditorUtils.load_texture(closed_path)

	var opened_path: String = sprite_opened_path_edit.text.strip_edges()
	interactable.sprite_opened = SparklingEditorUtils.load_texture(opened_path)

	# Rewards
	interactable.gold_reward = int(gold_reward_spin.value)
	interactable.item_rewards = _collect_item_rewards()

	# Interaction (cinematics from ResourcePickers)
	interactable.interaction_cinematic_id = interaction_cinematic_picker.get_selected_resource_id() if interaction_cinematic_picker else ""
	interactable.fallback_cinematic_id = fallback_cinematic_picker.get_selected_resource_id() if fallback_cinematic_picker else ""
	interactable.conditional_cinematics = _collect_conditional_cinematics()

	# Behavior
	interactable.one_shot = one_shot_check.button_pressed
	interactable.required_flags = SparklingEditorUtils.parse_flag_string(required_flags_edit.text)
	interactable.forbidden_flags = SparklingEditorUtils.parse_flag_string(forbidden_flags_edit.text)
	interactable.completion_flag = completion_flag_edit.text.strip_edges()


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	var res_id: String = name_id_group.get_id_value()
	if res_id.is_empty():
		errors.append("Interactable ID is required")

	# Get cinematic IDs from pickers (ResourcePicker validates existence via registry)
	var primary_id: String = interaction_cinematic_picker.get_selected_resource_id() if interaction_cinematic_picker else ""
	var fallback_id: String = fallback_cinematic_picker.get_selected_resource_id() if fallback_cinematic_picker else ""

	# Check if there's some form of interaction defined
	var has_rewards: bool = gold_reward_spin.value > 0 or not item_rewards_list.is_empty()
	var has_cinematic: bool = not primary_id.is_empty()
	var has_fallback: bool = not fallback_id.is_empty()
	var has_conditional: bool = _has_valid_conditional()

	if not has_rewards and not has_cinematic and not has_fallback and not has_conditional:
		warnings.append("Interactable has no rewards or cinematic - interaction will do nothing")

	# Note: ResourcePicker only shows valid cinematics from the registry,
	# so we don't need to validate existence here

	return {valid = errors.is_empty(), errors = errors, warnings = warnings}


## Override: Create a new interactable with defaults
func _create_new_resource() -> Resource:
	var new_interactable: InteractableData = InteractableData.new()
	new_interactable.interactable_id = "new_interactable"
	new_interactable.display_name = "New Interactable"
	new_interactable.interactable_type = InteractableData.InteractableType.CHEST
	new_interactable.one_shot = true
	new_interactable.gold_reward = 0
	new_interactable.interaction_cinematic_id = ""
	new_interactable.fallback_cinematic_id = ""
	new_interactable.completion_flag = ""

	return new_interactable


## Override: Get the display name from an interactable resource
func _get_resource_display_name(resource: Resource) -> String:
	if resource is InteractableData:
		var interactable: InteractableData = resource
		if not interactable.display_name.is_empty():
			return interactable.display_name
		if not interactable.interactable_id.is_empty():
			return interactable.interactable_id
	return "Unnamed Interactable"


# =============================================================================
# ITEM REWARDS - DynamicRowList Factory/Extractor Pattern
# =============================================================================

func _load_item_rewards(rewards: Array[Dictionary]) -> void:
	# Build data array for DynamicRowList
	var reward_data: Array[Dictionary] = []
	for reward: Dictionary in rewards:
		var reward_item_id: String = reward.get("item_id", "")
		var reward_quantity: int = reward.get("quantity", 1)
		reward_data.append({
			"item_id": reward_item_id,
			"quantity": reward_quantity
		})

	# Load into DynamicRowList
	item_rewards_list.load_data(reward_data)


## Row factory for item rewards - creates the UI for an item reward row
func _create_item_reward_row(data: Dictionary, row: HBoxContainer) -> void:
	var item_id: String = data.get("item_id", "")
	var quantity: int = data.get("quantity", 1)

	# Item picker
	var item_picker: ResourcePicker = ResourcePicker.new()
	item_picker.name = "ItemPicker"
	item_picker.resource_type = "item"
	item_picker.allow_none = true
	item_picker.none_text = "(Select Item)"
	item_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(item_picker)

	# Quantity label
	var qty_label: Label = Label.new()
	qty_label.text = "x"
	row.add_child(qty_label)

	# Quantity spinner
	var qty_spin: SpinBox = SpinBox.new()
	qty_spin.name = "QuantitySpin"
	qty_spin.min_value = 1
	qty_spin.max_value = 99
	qty_spin.value = quantity
	qty_spin.custom_minimum_size.x = 60
	qty_spin.tooltip_text = "Quantity of this item to grant"
	row.add_child(qty_spin)

	# Select item if provided (deferred to ensure picker is ready)
	if not item_id.is_empty():
		item_picker.call_deferred("select_by_id", "", item_id)


## Data extractor for item rewards - extracts data from an item reward row
func _extract_item_reward_data(row: HBoxContainer) -> Dictionary:
	var item_picker: ResourcePicker = row.get_node_or_null("ItemPicker") as ResourcePicker
	var qty_spin: SpinBox = row.get_node_or_null("QuantitySpin") as SpinBox

	if not item_picker or not item_picker.has_selection():
		return {}

	var item_id: String = item_picker.get_selected_resource_id()
	if item_id.is_empty():
		return {}

	var qty: int = int(qty_spin.value) if qty_spin else 1

	return {"item_id": item_id, "quantity": qty}


func _collect_item_rewards() -> Array[Dictionary]:
	return item_rewards_list.get_all_data()


func _refresh_item_reward_pickers() -> void:
	if not item_rewards_list:
		return
	for row: HBoxContainer in item_rewards_list.get_all_rows():
		var item_picker: ResourcePicker = row.get_node_or_null("ItemPicker") as ResourcePicker
		if item_picker:
			item_picker.refresh()


## Called when item reward data changes via DynamicRowList
func _on_item_reward_data_changed() -> void:
	if not _updating_ui:
		_mark_dirty()


# =============================================================================
# CONDITIONAL CINEMATICS - DynamicRowList Factory/Extractor Pattern
# =============================================================================

func _load_conditional_cinematics(conditionals: Array[Dictionary]) -> void:
	# Parse and load into DynamicRowList using shared component
	var conditional_data: Array[Dictionary] = ConditionalCinematicsRowFactory.parse_conditionals_for_loading(conditionals)
	conditionals_list.load_data(conditional_data)


func _collect_conditional_cinematics() -> Array[Dictionary]:
	return conditionals_list.get_all_data()


func _has_valid_conditional() -> bool:
	return ConditionalCinematicsRowFactory.has_valid_conditional(conditionals_list)


## Called when conditional data changes via DynamicRowList
func _on_conditional_data_changed() -> void:
	if not _updating_ui:
		_mark_dirty()


# =============================================================================
# UI EVENT HANDLERS
# =============================================================================

func _on_template_selected(index: int) -> void:
	if _updating_ui:
		return

	var template_key: String = template_option.get_item_metadata(index)
	if template_key.is_empty() or template_key == "custom":
		return

	var template: Dictionary = INTERACTABLE_TEMPLATES.get(template_key, {})
	if template.is_empty():
		return

	_updating_ui = true

	var template_name: String = template.get("name", "")
	if not template_name.is_empty():
		# Set name and auto-generate ID if unlocked
		var current_id: String = name_id_group.get_id_value()
		var auto_id: String = SparklingEditorUtils.generate_id_from_name(template_name)
		if not name_id_group.is_locked():
			name_id_group.set_values(template_name, auto_id, false)
		else:
			# Keep existing ID when locked
			name_id_group.set_values(template_name, current_id, false)

	var template_type: int = DictUtils.get_int(template, "type", 0)
	type_option.select(template_type)
	var template_one_shot: bool = template.get("one_shot", true)
	one_shot_check.button_pressed = template_one_shot

	_updating_ui = false
	_mark_dirty()


func _on_name_id_changed(_values: Dictionary) -> void:
	if _updating_ui:
		return
	_mark_dirty()


func _on_type_changed(_index: int) -> void:
	if _updating_ui:
		return
	_mark_dirty()
	_update_section_visibility()


func _update_section_visibility() -> void:
	var interactable_type: int = type_option.selected

	# Rewards section is most useful for chests/barrels
	var show_rewards: bool = interactable_type in [
		InteractableData.InteractableType.CHEST,
		InteractableData.InteractableType.BARREL,
		InteractableData.InteractableType.CUSTOM
	]
	rewards_section.visible = show_rewards


func _on_advanced_toggle() -> void:
	advanced_content.visible = not advanced_content.visible
	advanced_toggle_btn.text = "Advanced Options (expanded)" if advanced_content.visible else "Advanced Options"


## Called when primary or fallback cinematic picker selection changes
func _on_cinematic_picker_changed(_metadata: Dictionary, _field_type: String) -> void:
	if _updating_ui:
		return
	# ResourcePicker only shows valid cinematics, so no validation warnings needed
	# Hide any legacy warnings
	if interaction_warning_label:
		interaction_warning_label.visible = false
	if fallback_warning_label:
		fallback_warning_label.visible = false
	_mark_dirty()


func _on_field_changed(_value: Variant = null) -> void:
	if _updating_ui:
		return
	_mark_dirty()


func _on_check_changed(_pressed: bool) -> void:
	if _updating_ui:
		return
	_mark_dirty()


# =============================================================================
# SPRITE BROWSER
# =============================================================================

func _on_browse_sprite_closed() -> void:
	_current_sprite_target = "closed"
	_open_sprite_browser()


func _on_browse_sprite_opened() -> void:
	_current_sprite_target = "opened"
	_open_sprite_browser()


func _open_sprite_browser() -> void:
	if not sprite_file_dialog:
		sprite_file_dialog = EditorFileDialog.new()
		sprite_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		sprite_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		sprite_file_dialog.filters = PackedStringArray(["*.png ; PNG Images", "*.webp ; WebP Images", "*.jpg ; JPEG Images"])
		if not sprite_file_dialog.file_selected.is_connected(_on_sprite_file_selected):
			sprite_file_dialog.file_selected.connect(_on_sprite_file_selected)
		add_child(sprite_file_dialog)

	var default_path: String = _get_default_asset_path("sprites")
	sprite_file_dialog.current_dir = default_path
	sprite_file_dialog.popup_centered_ratio(0.7)


func _on_sprite_file_selected(path: String) -> void:
	if _current_sprite_target == "closed":
		sprite_closed_path_edit.text = path
		_load_sprite_preview(sprite_closed_preview, path)
	elif _current_sprite_target == "opened":
		sprite_opened_path_edit.text = path
		_load_sprite_preview(sprite_opened_preview, path)
	_mark_dirty()


func _on_sprite_closed_path_changed(new_text: String) -> void:
	if _updating_ui:
		return
	_load_sprite_preview(sprite_closed_preview, new_text)
	_mark_dirty()


func _on_sprite_opened_path_changed(new_text: String) -> void:
	if _updating_ui:
		return
	_load_sprite_preview(sprite_opened_preview, new_text)
	_mark_dirty()


func _on_clear_sprite_closed() -> void:
	sprite_closed_path_edit.text = ""
	sprite_closed_preview.texture = null
	sprite_closed_preview.tooltip_text = "No sprite assigned"
	_mark_dirty()


func _on_clear_sprite_opened() -> void:
	sprite_opened_path_edit.text = ""
	sprite_opened_preview.texture = null
	sprite_opened_preview.tooltip_text = "No sprite assigned"
	_mark_dirty()


func _load_sprite_preview(preview: TextureRect, path: String) -> void:
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty():
		preview.texture = null
		preview.tooltip_text = "No sprite assigned"
		return

	if ResourceLoader.exists(clean_path):
		var loaded: Resource = load(clean_path)
		var texture: Texture2D = loaded if loaded is Texture2D else null
		preview.texture = texture
		preview.tooltip_text = clean_path
	else:
		preview.texture = null
		preview.tooltip_text = "File not found: " + clean_path




# =============================================================================
# PLACE ON MAP (using MapPlacementHelper)
# =============================================================================

func _on_place_on_map_pressed() -> void:
	if not current_resource:
		_show_error("No interactable selected.")
		return

	# Auto-save if resource is unsaved or has pending changes
	var needs_save: bool = current_resource.resource_path.is_empty() or is_dirty
	if needs_save:
		# Show brief saving feedback
		_show_success_message("Saving...")

		# Validate before saving
		var validation: Dictionary = _validate_resource()
		if not validation.valid:
			_show_errors(validation.errors)
			return

		# Perform the save
		_save_resource_data()

		# Determine save path for new resources
		var save_path: String = current_resource.resource_path
		if save_path.is_empty():
			var save_dir: String = ""
			if resource_type_id != "" and ModLoader:
				var active_mod: ModManifest = ModLoader.get_active_mod()
				if active_mod:
					var resource_dirs: Dictionary = ModLoader.get_resource_directories(active_mod.mod_id)
					if resource_type_id in resource_dirs:
						save_dir = DictUtils.get_string(resource_dirs, resource_type_id, "")
			if save_dir.is_empty():
				_show_error("No save directory available. Please set an active mod.")
				return
			var interactable_id: String = name_id_group.get_id_value()
			var filename: String = interactable_id + ".tres" if not interactable_id.is_empty() else "new_interactable_%d.tres" % Time.get_unix_time_from_system()
			save_path = save_dir.path_join(filename)

		var err: Error = ResourceSaver.save(current_resource, save_path)
		if err != OK:
			_show_error("Failed to save interactable: " + str(err))
			return

		# Update resource path and clear dirty flag
		current_resource.take_over_path(save_path)
		current_resource_path = save_path
		is_dirty = false
		_hide_errors()
		_refresh_list()

	place_on_map_dialog.show_dialog()


## Handle map selection from the PlaceOnMapDialog component
func _on_map_selection_confirmed(map_path: String) -> void:
	var interactable_path: String = current_resource.resource_path
	var grid_x: int = int(place_position_x.value)
	var grid_y: int = int(place_position_y.value)
	var interactable_id: String = name_id_group.get_id_value()
	var node_name: String = interactable_id.to_pascal_case() if not interactable_id.is_empty() else "Interactable"

	var success: bool = map_placement_helper.place_interactable_on_map(map_path, interactable_path, node_name, Vector2i(grid_x, grid_y))
	if not success:
		_show_error("Failed to place interactable on map. Check the output for details.")


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _get_default_asset_path(asset_type: String) -> String:
	var mod_path: String = SparklingEditorUtils.get_active_mod_path()
	if mod_path.is_empty():
		return "res://mods/"

	var assets_dir: String = mod_path.path_join("assets/" + asset_type + "/")
	if DirAccess.dir_exists_absolute(assets_dir):
		return assets_dir

	var generic_assets_dir: String = mod_path.path_join("assets/")
	if DirAccess.dir_exists_absolute(generic_assets_dir):
		return generic_assets_dir

	return mod_path
