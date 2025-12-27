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

var interactable_id_edit: LineEdit
var interactable_id_lock_btn: Button
var display_name_edit: LineEdit
var type_option: OptionButton
var template_option: OptionButton

# Track if ID should auto-generate from name
var _id_is_locked: bool = false

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
var item_rewards_container: VBoxContainer
var add_item_reward_btn: Button
var gold_reward_spin: SpinBox

# Track item reward entries for dynamic UI
var _item_reward_entries: Array[Dictionary] = []

# =============================================================================
# UI FIELD REFERENCES - Interaction
# =============================================================================

var simple_interaction_section: VBoxContainer
var dialog_text_edit: TextEdit
var dialog_status_label: Label

var advanced_section: VBoxContainer
var advanced_toggle_btn: Button
var advanced_content: VBoxContainer

var interaction_cinematic_edit: LineEdit
var interaction_warning_label: Label
var fallback_cinematic_edit: LineEdit
var fallback_warning_label: Label

# =============================================================================
# UI FIELD REFERENCES - Conditional Cinematics
# =============================================================================

var conditionals_container: VBoxContainer
var add_conditional_btn: Button
var _conditional_entries: Array[Dictionary] = []

# =============================================================================
# UI FIELD REFERENCES - Behavior
# =============================================================================

var one_shot_check: CheckBox
var required_flags_edit: LineEdit
var forbidden_flags_edit: LineEdit
var completion_flag_edit: LineEdit

# =============================================================================
# STATE TRACKING
# =============================================================================

# Flag to prevent signal feedback loops during UI updates
var _updating_ui: bool = false


func _ready() -> void:
	resource_type_name = "Interactable"
	resource_type_id = "interactable"
	# Depend on items for the reward picker
	resource_dependencies = ["item"]
	super._ready()

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
	_add_simple_interaction_section()
	_add_advanced_options_section()

	# Add the button container at the end (with separator for visual clarity)
	_add_button_container_to_detail_panel()


func _add_basic_info_section() -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Basic Information", detail_panel)

	# Template selector
	var template_row: HBoxContainer = SparklingEditorUtils.create_field_row("Start from:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	template_option = OptionButton.new()
	template_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var idx: int = 0
	for key: String in INTERACTABLE_TEMPLATES.keys():
		var template: Dictionary = INTERACTABLE_TEMPLATES[key]
		var template_label: String = template.get("label", key)
		template_option.add_item(template_label, idx)
		template_option.set_item_metadata(idx, key)
		idx += 1
	template_option.item_selected.connect(_on_template_selected)
	template_row.add_child(template_option)

	SparklingEditorUtils.create_help_label("Choose a template to pre-fill common interactable types", section)

	# Display Name
	var name_row: HBoxContainer = SparklingEditorUtils.create_field_row("Display Name:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	display_name_edit = LineEdit.new()
	display_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_name_edit.placeholder_text = "Treasure Chest, Dusty Bookshelf..."
	display_name_edit.tooltip_text = "Name shown in messages and UI. E.g., 'Treasure Chest', 'Old Sign'."
	display_name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(display_name_edit)

	# Interactable ID
	var id_row: HBoxContainer = SparklingEditorUtils.create_field_row("Interactable ID:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	interactable_id_edit = LineEdit.new()
	interactable_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interactable_id_edit.placeholder_text = "(auto-generated from name)"
	interactable_id_edit.tooltip_text = "Unique ID for referencing this interactable. Auto-generates from name."
	interactable_id_edit.text_changed.connect(_on_id_manually_changed)
	id_row.add_child(interactable_id_edit)

	interactable_id_lock_btn = Button.new()
	interactable_id_lock_btn.text = "Unlock"
	interactable_id_lock_btn.tooltip_text = "Lock ID to prevent auto-generation"
	interactable_id_lock_btn.custom_minimum_size.x = 60
	interactable_id_lock_btn.pressed.connect(_on_id_lock_toggled)
	id_row.add_child(interactable_id_lock_btn)

	SparklingEditorUtils.create_help_label("ID auto-generates from name. Click lock to set custom ID.", section)

	# Interactable Type
	var type_row: HBoxContainer = SparklingEditorUtils.create_field_row("Type:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	type_option = OptionButton.new()
	type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_option.tooltip_text = "Determines default behavior and editor suggestions."
	type_option.add_item("Chest", InteractableData.InteractableType.CHEST)
	type_option.add_item("Bookshelf", InteractableData.InteractableType.BOOKSHELF)
	type_option.add_item("Barrel", InteractableData.InteractableType.BARREL)
	type_option.add_item("Sign", InteractableData.InteractableType.SIGN)
	type_option.add_item("Lever", InteractableData.InteractableType.LEVER)
	type_option.add_item("Custom", InteractableData.InteractableType.CUSTOM)
	type_option.item_selected.connect(_on_type_changed)
	type_row.add_child(type_option)

	SparklingEditorUtils.create_help_label("Chest/Barrel = one-shot items. Bookshelf/Sign = repeatable text. Lever = state toggle.", section)


func _add_appearance_section() -> void:
	appearance_section = SparklingEditorUtils.create_section("Appearance", detail_panel)

	# Sprite Closed
	var closed_row: HBoxContainer = SparklingEditorUtils.create_field_row("Sprite (Closed):", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, appearance_section)

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

	# Sprite Opened
	var opened_row: HBoxContainer = SparklingEditorUtils.create_field_row("Sprite (Opened):", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, appearance_section)

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

	SparklingEditorUtils.create_help_label("32x32 sprites recommended. Opened sprite is optional (one-shot items stay opened).", appearance_section)


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
	rewards_section = SparklingEditorUtils.create_section("Rewards", detail_panel)

	SparklingEditorUtils.create_help_label("Items and gold granted when this interactable is searched. Best for chests/barrels.", rewards_section)

	# Gold reward
	var gold_row: HBoxContainer = SparklingEditorUtils.create_field_row("Gold:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, rewards_section)
	gold_reward_spin = SpinBox.new()
	gold_reward_spin.min_value = 0
	gold_reward_spin.max_value = 999999
	gold_reward_spin.value = 0
	gold_reward_spin.tooltip_text = "Amount of gold to grant when searched"
	gold_reward_spin.value_changed.connect(_on_field_changed)
	gold_row.add_child(gold_reward_spin)

	# Item rewards header and add button
	var items_header: HBoxContainer = HBoxContainer.new()
	items_header.add_theme_constant_override("separation", 8)
	rewards_section.add_child(items_header)

	var items_label: Label = Label.new()
	items_label.text = "Item Rewards:"
	items_header.add_child(items_label)

	add_item_reward_btn = Button.new()
	add_item_reward_btn.text = "+ Add Item"
	add_item_reward_btn.tooltip_text = "Add an item reward to this interactable"
	add_item_reward_btn.pressed.connect(_on_add_item_reward)
	items_header.add_child(add_item_reward_btn)

	# Container for item reward entries
	item_rewards_container = VBoxContainer.new()
	item_rewards_container.add_theme_constant_override("separation", 4)
	rewards_section.add_child(item_rewards_container)


func _add_simple_interaction_section() -> void:
	simple_interaction_section = SparklingEditorUtils.create_section("What does it say?", detail_panel)

	dialog_status_label = Label.new()
	dialog_status_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	dialog_status_label.visible = false
	simple_interaction_section.add_child(dialog_status_label)

	dialog_text_edit = TextEdit.new()
	dialog_text_edit.placeholder_text = "The bookshelf is filled with dusty tomes.\nNothing catches your eye."
	dialog_text_edit.custom_minimum_size.y = 80
	dialog_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_text_edit.scroll_fit_content_height = true
	dialog_text_edit.tooltip_text = "Text shown when interacted with. Each line is a separate dialog box. For chests with items, this shows AFTER 'Found [item]!' messages."
	dialog_text_edit.text_changed.connect(_on_dialog_text_changed)
	simple_interaction_section.add_child(dialog_text_edit)

	SparklingEditorUtils.create_help_label("For signs/bookshelves: just type the message. For chests: optional message after finding items.", simple_interaction_section)


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
	var section: VBoxContainer = SparklingEditorUtils.create_section("Manual Cinematic Assignment", parent)

	var primary_row: HBoxContainer = SparklingEditorUtils.create_field_row("Interaction Cinematic:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	interaction_cinematic_edit = LineEdit.new()
	interaction_cinematic_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interaction_cinematic_edit.placeholder_text = "cinematic_id (overrides dialog_text)"
	interaction_cinematic_edit.tooltip_text = "Explicit cinematic to play. Overrides auto-generated dialog if set."
	interaction_cinematic_edit.text_changed.connect(_on_cinematic_field_changed.bind("primary"))
	primary_row.add_child(interaction_cinematic_edit)

	interaction_warning_label = Label.new()
	interaction_warning_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	interaction_warning_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	interaction_warning_label.visible = false
	section.add_child(interaction_warning_label)

	SparklingEditorUtils.create_help_label("Leave empty to auto-generate from dialog_text and rewards", section)

	var fallback_row: HBoxContainer = SparklingEditorUtils.create_field_row("Fallback Cinematic:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	fallback_cinematic_edit = LineEdit.new()
	fallback_cinematic_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fallback_cinematic_edit.placeholder_text = "fallback_cinematic_id"
	fallback_cinematic_edit.tooltip_text = "Cinematic to play if no conditions match and no primary cinematic set."
	fallback_cinematic_edit.text_changed.connect(_on_cinematic_field_changed.bind("fallback"))
	fallback_row.add_child(fallback_cinematic_edit)

	fallback_warning_label = Label.new()
	fallback_warning_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	fallback_warning_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	fallback_warning_label.visible = false
	section.add_child(fallback_warning_label)


func _add_conditional_cinematics_section_to(parent: Control) -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Conditional Cinematics", parent)

	add_conditional_btn = Button.new()
	add_conditional_btn.text = "+ Add Condition"
	add_conditional_btn.pressed.connect(_on_add_conditional)
	section.add_child(add_conditional_btn)

	SparklingEditorUtils.create_help_label("Conditions checked in order. First matching condition's cinematic plays.", section)

	conditionals_container = VBoxContainer.new()
	conditionals_container.add_theme_constant_override("separation", 4)
	section.add_child(conditionals_container)


func _add_behavior_section_to(parent: Control) -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Behavior", parent)

	# One Shot
	one_shot_check = CheckBox.new()
	one_shot_check.text = "One-Shot (can only be searched once)"
	one_shot_check.button_pressed = true
	one_shot_check.tooltip_text = "If checked, this interactable can only be used once and will be marked as opened."
	one_shot_check.toggled.connect(_on_check_changed)
	section.add_child(one_shot_check)

	SparklingEditorUtils.create_help_label("One-shot: chests, barrels (grant items once). Repeatable: signs, bookshelves (read multiple times).", section)

	# Required Flags
	var required_row: HBoxContainer = SparklingEditorUtils.create_field_row("Required Flags:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	required_flags_edit = LineEdit.new()
	required_flags_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	required_flags_edit.placeholder_text = "flag1, flag2 (comma-separated)"
	required_flags_edit.tooltip_text = "All these flags must be set for the player to interact. Leave empty for always available."
	required_flags_edit.text_changed.connect(_on_field_changed)
	required_row.add_child(required_flags_edit)

	# Forbidden Flags
	var forbidden_row: HBoxContainer = SparklingEditorUtils.create_field_row("Forbidden Flags:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	forbidden_flags_edit = LineEdit.new()
	forbidden_flags_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forbidden_flags_edit.placeholder_text = "flag1, flag2 (comma-separated)"
	forbidden_flags_edit.tooltip_text = "If ANY of these flags are set, interaction is blocked."
	forbidden_flags_edit.text_changed.connect(_on_field_changed)
	forbidden_row.add_child(forbidden_flags_edit)

	# Completion Flag
	var completion_row: HBoxContainer = SparklingEditorUtils.create_field_row("Completion Flag:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	completion_flag_edit = LineEdit.new()
	completion_flag_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	completion_flag_edit.placeholder_text = "(auto: {interactable_id}_opened)"
	completion_flag_edit.tooltip_text = "Flag set after successful interaction. Auto-generated if empty."
	completion_flag_edit.text_changed.connect(_on_field_changed)
	completion_row.add_child(completion_flag_edit)

	SparklingEditorUtils.create_help_label("Completion flag tracks opened state. Leave empty for auto-generated '{id}_opened'.", section)


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

	# Basic info
	display_name_edit.text = interactable.display_name
	interactable_id_edit.text = interactable.interactable_id

	var expected_auto_id: String = SparklingEditorUtils.generate_id_from_name(interactable.display_name)
	_id_is_locked = (interactable.interactable_id != expected_auto_id) and not interactable.interactable_id.is_empty()
	_update_lock_button()

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

	# Interaction
	dialog_text_edit.text = interactable.dialog_text
	interaction_cinematic_edit.text = interactable.interaction_cinematic_id
	fallback_cinematic_edit.text = interactable.fallback_cinematic_id
	_load_conditional_cinematics(interactable.conditional_cinematics)

	# Behavior
	one_shot_check.button_pressed = interactable.one_shot
	required_flags_edit.text = ", ".join(interactable.required_flags)
	forbidden_flags_edit.text = ", ".join(interactable.forbidden_flags)
	completion_flag_edit.text = interactable.completion_flag

	_updating_ui = false

	call_deferred("_update_cinematic_warnings")
	call_deferred("_update_dialog_status")


## Override: Save UI data to resource
func _save_resource_data() -> void:
	if not current_resource is InteractableData:
		return
	var interactable: InteractableData = current_resource

	# Basic info
	interactable.interactable_id = interactable_id_edit.text.strip_edges()
	interactable.display_name = display_name_edit.text.strip_edges()
	interactable.interactable_type = type_option.selected as InteractableData.InteractableType

	# Appearance
	var closed_path: String = sprite_closed_path_edit.text.strip_edges()
	interactable.sprite_closed = _load_texture(closed_path)

	var opened_path: String = sprite_opened_path_edit.text.strip_edges()
	interactable.sprite_opened = _load_texture(opened_path)

	# Rewards
	interactable.gold_reward = int(gold_reward_spin.value)
	interactable.item_rewards = _collect_item_rewards()

	# Interaction
	interactable.dialog_text = dialog_text_edit.text
	interactable.interaction_cinematic_id = interaction_cinematic_edit.text.strip_edges()
	interactable.fallback_cinematic_id = fallback_cinematic_edit.text.strip_edges()
	interactable.conditional_cinematics = _collect_conditional_cinematics()

	# Behavior
	interactable.one_shot = one_shot_check.button_pressed
	interactable.required_flags = _parse_flag_list(required_flags_edit.text)
	interactable.forbidden_flags = _parse_flag_list(forbidden_flags_edit.text)
	interactable.completion_flag = completion_flag_edit.text.strip_edges()


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	var res_id: String = interactable_id_edit.text.strip_edges()
	if res_id.is_empty():
		errors.append("Interactable ID is required")

	# Check if there's some form of interaction defined
	var has_rewards: bool = gold_reward_spin.value > 0 or not _item_reward_entries.is_empty()
	var has_dialog: bool = not dialog_text_edit.text.strip_edges().is_empty()
	var has_cinematic: bool = not interaction_cinematic_edit.text.strip_edges().is_empty()
	var has_fallback: bool = not fallback_cinematic_edit.text.strip_edges().is_empty()
	var has_conditional: bool = _has_valid_conditional()

	if not has_rewards and not has_dialog and not has_cinematic and not has_fallback and not has_conditional:
		warnings.append("Interactable has no rewards, dialog, or cinematic - interaction will do nothing")

	# Check cinematic existence
	var cinematics_dir: String = _get_active_mod_cinematics_path()
	var primary_id: String = interaction_cinematic_edit.text.strip_edges()
	var fallback_id: String = fallback_cinematic_edit.text.strip_edges()

	if not primary_id.is_empty() and not _cinematic_exists(cinematics_dir, primary_id):
		warnings.append("Interaction cinematic '%s' not found in loaded mods" % primary_id)

	if not fallback_id.is_empty() and not _cinematic_exists(cinematics_dir, fallback_id):
		warnings.append("Fallback cinematic '%s' not found in loaded mods" % fallback_id)

	return {valid = errors.is_empty(), errors = errors, warnings = warnings}


## Override: Create a new interactable with defaults
func _create_new_resource() -> Resource:
	var new_interactable: InteractableData = InteractableData.new()
	new_interactable.interactable_id = "new_interactable"
	new_interactable.display_name = "New Interactable"
	new_interactable.interactable_type = InteractableData.InteractableType.CHEST
	new_interactable.one_shot = true
	new_interactable.gold_reward = 0
	new_interactable.dialog_text = ""
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
# ITEM REWARDS UI
# =============================================================================

func _load_item_rewards(rewards: Array[Dictionary]) -> void:
	_clear_item_reward_entries()
	for reward: Dictionary in rewards:
		var reward_item_id: String = reward.get("item_id", "")
		var reward_quantity: int = reward.get("quantity", 1)
		_add_item_reward_entry(reward_item_id, reward_quantity)


func _add_item_reward_entry(item_id: String = "", quantity: int = 1) -> void:
	var entry_container: HBoxContainer = HBoxContainer.new()
	entry_container.add_theme_constant_override("separation", 4)

	# Item picker
	var item_picker: ResourcePicker = ResourcePicker.new()
	item_picker.resource_type = "item"
	item_picker.allow_none = true
	item_picker.none_text = "(Select Item)"
	item_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_picker.resource_selected.connect(_on_item_reward_changed)
	entry_container.add_child(item_picker)

	# Quantity spinner
	var qty_label: Label = Label.new()
	qty_label.text = "x"
	entry_container.add_child(qty_label)

	var qty_spin: SpinBox = SpinBox.new()
	qty_spin.min_value = 1
	qty_spin.max_value = 99
	qty_spin.value = quantity
	qty_spin.custom_minimum_size.x = 60
	qty_spin.tooltip_text = "Quantity of this item to grant"
	qty_spin.value_changed.connect(_on_field_changed)
	entry_container.add_child(qty_spin)

	# Remove button
	var remove_btn: Button = Button.new()
	remove_btn.text = "X"
	remove_btn.tooltip_text = "Remove this item reward"
	remove_btn.custom_minimum_size.x = 30
	remove_btn.pressed.connect(_on_remove_item_reward.bind(entry_container))
	entry_container.add_child(remove_btn)

	item_rewards_container.add_child(entry_container)

	# Select item if provided
	if not item_id.is_empty() and ModLoader and ModLoader.registry:
		var item_res: ItemData = ModLoader.registry.get_item(item_id)
		if item_res:
			item_picker.select_resource(item_res)

	_item_reward_entries.append({
		"container": entry_container,
		"item_picker": item_picker,
		"quantity_spin": qty_spin
	})


func _clear_item_reward_entries() -> void:
	for entry: Dictionary in _item_reward_entries:
		var container_val: Variant = entry.get("container")
		var container: Control = container_val if container_val is Control else null
		if container and is_instance_valid(container):
			container.queue_free()
	_item_reward_entries.clear()


func _collect_item_rewards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _item_reward_entries:
		var picker_val: Variant = entry.get("item_picker")
		var item_picker: ResourcePicker = picker_val if picker_val is ResourcePicker else null
		var spin_val: Variant = entry.get("quantity_spin")
		var qty_spin: SpinBox = spin_val if spin_val is SpinBox else null

		if not item_picker or not item_picker.has_selection():
			continue

		var item_res: Resource = item_picker.get_selected_resource()
		if not item_res:
			continue

		var item_id: String = item_res.resource_path.get_file().get_basename()
		var quantity: int = int(qty_spin.value) if qty_spin else 1

		result.append({"item_id": item_id, "quantity": quantity})

	return result


func _refresh_item_reward_pickers() -> void:
	for entry: Dictionary in _item_reward_entries:
		var picker_val: Variant = entry.get("item_picker")
		var item_picker: ResourcePicker = picker_val if picker_val is ResourcePicker else null
		if item_picker:
			item_picker.refresh()


func _on_add_item_reward() -> void:
	_add_item_reward_entry()


func _on_remove_item_reward(entry_container: HBoxContainer) -> void:
	for i: int in range(_item_reward_entries.size()):
		if _item_reward_entries[i].get("container") == entry_container:
			_item_reward_entries.remove_at(i)
			break
	entry_container.queue_free()


func _on_item_reward_changed(_metadata: Dictionary) -> void:
	if _updating_ui:
		return
	_mark_dirty()


# =============================================================================
# CONDITIONAL CINEMATICS UI
# =============================================================================

func _load_conditional_cinematics(conditionals: Array[Dictionary]) -> void:
	_clear_conditional_entries()
	for cond: Dictionary in conditionals:
		var flags_and: Array = []
		var single_flag: String = cond.get("flag", "")
		if not single_flag.is_empty():
			flags_and.append(single_flag)
		var explicit_flags: Array = cond.get("flags", [])
		for flag: String in explicit_flags:
			if not flag.is_empty() and flag not in flags_and:
				flags_and.append(flag)

		var flags_or: Array = cond.get("any_flags", [])
		var negate: bool = cond.get("negate", false)
		var cinematic_id: String = cond.get("cinematic_id", "")

		_add_conditional_entry(flags_and, flags_or, negate, cinematic_id)


func _add_conditional_entry(flags_and: Array = [], flags_or: Array = [], negate: bool = false, cinematic_id: String = "") -> void:
	var entry_container: VBoxContainer = VBoxContainer.new()
	entry_container.add_theme_constant_override("separation", 2)

	var panel: PanelContainer = PanelContainer.new()
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.2, 0.5)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.3, 0.3, 0.4, 0.8)
	panel_style.set_content_margin_all(6)
	panel_style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", panel_style)

	var panel_content: VBoxContainer = VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 4)
	panel.add_child(panel_content)
	entry_container.add_child(panel)

	# AND flags row
	var and_row: HBoxContainer = HBoxContainer.new()
	and_row.add_theme_constant_override("separation", 4)
	panel_content.add_child(and_row)

	var and_label: Label = Label.new()
	and_label.text = "ALL of:"
	and_label.tooltip_text = "All these flags must be set (AND logic)"
	and_label.custom_minimum_size.x = 55
	and_row.add_child(and_label)

	var and_flags_edit: LineEdit = LineEdit.new()
	and_flags_edit.placeholder_text = "flag1, flag2 (comma-separated)"
	and_flags_edit.text = ", ".join(flags_and) if not flags_and.is_empty() else ""
	and_flags_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	and_flags_edit.tooltip_text = "Enter flag names separated by commas. ALL must be set for condition to match."
	and_flags_edit.text_changed.connect(_on_field_changed)
	and_row.add_child(and_flags_edit)

	# OR flags row
	var or_row: HBoxContainer = HBoxContainer.new()
	or_row.add_theme_constant_override("separation", 4)
	panel_content.add_child(or_row)

	var or_label: Label = Label.new()
	or_label.text = "ANY of:"
	or_label.tooltip_text = "At least one of these flags must be set (OR logic)"
	or_label.custom_minimum_size.x = 55
	or_row.add_child(or_label)

	var or_flags_edit: LineEdit = LineEdit.new()
	or_flags_edit.placeholder_text = "flagA, flagB (at least one)"
	or_flags_edit.text = ", ".join(flags_or) if not flags_or.is_empty() else ""
	or_flags_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	or_flags_edit.tooltip_text = "Enter flag names separated by commas. At least ONE must be set for condition to match."
	or_flags_edit.text_changed.connect(_on_field_changed)
	or_row.add_child(or_flags_edit)

	# Cinematic row
	var cinematic_row: HBoxContainer = HBoxContainer.new()
	cinematic_row.add_theme_constant_override("separation", 4)
	panel_content.add_child(cinematic_row)

	var negate_check: CheckBox = CheckBox.new()
	negate_check.text = "NOT"
	negate_check.tooltip_text = "Invert the condition (trigger when flags are NOT matched)"
	negate_check.button_pressed = negate
	negate_check.toggled.connect(_on_check_changed)
	cinematic_row.add_child(negate_check)

	var arrow: Label = Label.new()
	arrow.text = "->"
	cinematic_row.add_child(arrow)

	var cinematic_edit: LineEdit = LineEdit.new()
	cinematic_edit.placeholder_text = "cinematic_id"
	cinematic_edit.text = cinematic_id
	cinematic_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cinematic_edit.custom_minimum_size.x = 150
	cinematic_edit.tooltip_text = "The cinematic to play when this condition is met"
	cinematic_edit.text_changed.connect(_on_field_changed)
	cinematic_row.add_child(cinematic_edit)

	var remove_btn: Button = Button.new()
	remove_btn.text = "X"
	remove_btn.tooltip_text = "Remove this condition"
	remove_btn.custom_minimum_size.x = 30
	remove_btn.pressed.connect(_on_remove_conditional.bind(entry_container))
	cinematic_row.add_child(remove_btn)

	conditionals_container.add_child(entry_container)
	_conditional_entries.append({
		"container": entry_container,
		"and_flags_edit": and_flags_edit,
		"or_flags_edit": or_flags_edit,
		"negate_check": negate_check,
		"cinematic_edit": cinematic_edit
	})


func _clear_conditional_entries() -> void:
	for entry: Dictionary in _conditional_entries:
		var container_val: Variant = entry.get("container")
		var container: Control = container_val if container_val is Control else null
		if container and is_instance_valid(container):
			container.queue_free()
	_conditional_entries.clear()


func _collect_conditional_cinematics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _conditional_entries:
		var and_val: Variant = entry.get("and_flags_edit")
		var and_flags_edit: LineEdit = and_val if and_val is LineEdit else null
		var or_val: Variant = entry.get("or_flags_edit")
		var or_flags_edit: LineEdit = or_val if or_val is LineEdit else null
		var negate_val: Variant = entry.get("negate_check")
		var negate_check: CheckBox = negate_val if negate_val is CheckBox else null
		var cine_val: Variant = entry.get("cinematic_edit")
		var cinematic_edit: LineEdit = cine_val if cine_val is LineEdit else null

		if not cinematic_edit:
			continue

		var cine_text: String = cinematic_edit.text.strip_edges()

		var and_flags: Array[String] = _parse_flag_list(and_flags_edit.text if and_flags_edit else "")
		var or_flags: Array[String] = _parse_flag_list(or_flags_edit.text if or_flags_edit else "")

		if and_flags.is_empty() and or_flags.is_empty() and cine_text.is_empty():
			continue

		var cond_dict: Dictionary = {"cinematic_id": cine_text}

		if not and_flags.is_empty():
			cond_dict["flags"] = and_flags
		if not or_flags.is_empty():
			cond_dict["any_flags"] = or_flags
		if negate_check and negate_check.button_pressed:
			cond_dict["negate"] = true

		result.append(cond_dict)

	return result


func _has_valid_conditional() -> bool:
	for entry: Dictionary in _conditional_entries:
		var and_val: Variant = entry.get("and_flags_edit")
		var and_flags_edit: LineEdit = and_val if and_val is LineEdit else null
		var or_val: Variant = entry.get("or_flags_edit")
		var or_flags_edit: LineEdit = or_val if or_val is LineEdit else null
		var cine_val: Variant = entry.get("cinematic_edit")
		var cinematic_edit: LineEdit = cine_val if cine_val is LineEdit else null

		if not cinematic_edit:
			continue

		var cine_text: String = cinematic_edit.text.strip_edges()
		if cine_text.is_empty():
			continue

		var has_and_flags: bool = and_flags_edit and not and_flags_edit.text.strip_edges().is_empty()
		var has_or_flags: bool = or_flags_edit and not or_flags_edit.text.strip_edges().is_empty()

		if has_and_flags or has_or_flags:
			return true

	return false


func _on_add_conditional() -> void:
	_add_conditional_entry()


func _on_remove_conditional(entry_container: VBoxContainer) -> void:
	for i: int in range(_conditional_entries.size()):
		if _conditional_entries[i].get("container") == entry_container:
			_conditional_entries.remove_at(i)
			break
	entry_container.queue_free()


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
		display_name_edit.text = template_name
		if not _id_is_locked:
			interactable_id_edit.text = SparklingEditorUtils.generate_id_from_name(template_name)

	var template_type: int = DictUtils.get_int(template, "type", 0)
	type_option.select(template_type)
	var template_one_shot: bool = template.get("one_shot", true)
	one_shot_check.button_pressed = template_one_shot

	var template_dialog: String = template.get("dialog", "")
	if not template_dialog.is_empty():
		dialog_text_edit.text = template_dialog

	_updating_ui = false

	var template_label: String = template.get("label", template_key)
	_show_dialog_status("Applied '%s' template - customize as needed!" % template_label, Color(0.5, 0.8, 1.0))


func _on_name_changed(new_name: String) -> void:
	if _updating_ui:
		return
	if not _id_is_locked:
		interactable_id_edit.text = SparklingEditorUtils.generate_id_from_name(new_name)
	_mark_dirty()


func _on_id_manually_changed(_text: String) -> void:
	if _updating_ui:
		return
	if not _id_is_locked and interactable_id_edit.has_focus():
		_id_is_locked = true
		_update_lock_button()
	_mark_dirty()


func _on_id_lock_toggled() -> void:
	_id_is_locked = not _id_is_locked
	_update_lock_button()
	if not _id_is_locked:
		interactable_id_edit.text = SparklingEditorUtils.generate_id_from_name(display_name_edit.text)


func _update_lock_button() -> void:
	interactable_id_lock_btn.text = "Lock" if _id_is_locked else "Unlock"
	interactable_id_lock_btn.tooltip_text = "ID is locked. Click to unlock and auto-generate." if _id_is_locked else "ID auto-generates from name. Click to lock."


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

	# Dialog section is useful for everything
	# But update placeholder text based on type
	match interactable_type:
		InteractableData.InteractableType.BOOKSHELF:
			dialog_text_edit.placeholder_text = "The bookshelf is filled with dusty tomes.\nNothing catches your eye."
		InteractableData.InteractableType.SIGN:
			dialog_text_edit.placeholder_text = "Welcome to our village!"
		InteractableData.InteractableType.CHEST, InteractableData.InteractableType.BARREL:
			dialog_text_edit.placeholder_text = "(Optional message after finding items)"
		InteractableData.InteractableType.LEVER:
			dialog_text_edit.placeholder_text = "You pull the lever..."
		_:
			dialog_text_edit.placeholder_text = "What happens when interacted with?"


func _on_dialog_text_changed() -> void:
	if _updating_ui:
		return
	_mark_dirty()
	_update_dialog_status()


func _update_dialog_status() -> void:
	if not dialog_status_label:
		return

	var has_dialog: bool = not dialog_text_edit.text.strip_edges().is_empty()
	var has_cinematic: bool = not interaction_cinematic_edit.text.strip_edges().is_empty()

	if has_cinematic:
		_show_dialog_status("Using explicit cinematic - dialog_text will be ignored", Color(0.6, 0.8, 1.0))
	elif has_dialog:
		_show_dialog_status("Dialog will auto-generate cinematic at runtime", Color(0.4, 0.9, 0.4))
	else:
		dialog_status_label.visible = false


func _show_dialog_status(message: String, color: Color) -> void:
	if dialog_status_label:
		dialog_status_label.text = message
		dialog_status_label.add_theme_color_override("font_color", color)
		dialog_status_label.visible = true


func _on_advanced_toggle() -> void:
	advanced_content.visible = not advanced_content.visible
	advanced_toggle_btn.text = "Advanced Options (expanded)" if advanced_content.visible else "Advanced Options"


func _on_cinematic_field_changed(text: String, field_type: String) -> void:
	if _updating_ui:
		return
	_mark_dirty()
	_validate_cinematic_field(text.strip_edges(), field_type)
	_update_dialog_status()


func _validate_cinematic_field(cinematic_id: String, field_type: String) -> void:
	var warning_label: Label = interaction_warning_label if field_type == "primary" else fallback_warning_label if field_type == "fallback" else null
	if not warning_label:
		return
	if cinematic_id.is_empty():
		warning_label.visible = false
		return
	var cinematics_dir: String = _get_active_mod_cinematics_path()
	if _cinematic_exists(cinematics_dir, cinematic_id):
		warning_label.visible = false
	else:
		warning_label.text = "Cinematic '%s' not found in any loaded mod" % cinematic_id
		warning_label.visible = true


func _update_cinematic_warnings() -> void:
	_validate_cinematic_field(interaction_cinematic_edit.text.strip_edges() if interaction_cinematic_edit else "", "primary")
	_validate_cinematic_field(fallback_cinematic_edit.text.strip_edges() if fallback_cinematic_edit else "", "fallback")


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


## Helper to safely load a texture from path
func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded: Resource = load(path)
	return loaded if loaded is Texture2D else null


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _parse_flag_list(text: String) -> Array[String]:
	var flags: Array[String] = []
	var clean_text: String = text.strip_edges()
	if clean_text.is_empty():
		return flags

	var parts: PackedStringArray = clean_text.split(",")
	for part: String in parts:
		var trimmed: String = part.strip_edges()
		if not trimmed.is_empty():
			flags.append(trimmed)

	return flags


func _get_active_mod_cinematics_path() -> String:
	var mod_path: String = SparklingEditorUtils.get_active_mod_path()
	if mod_path.is_empty():
		return ""
	return mod_path.path_join("data/cinematics/")


func _cinematic_exists(cinematics_dir: String, cinematic_id: String) -> bool:
	if cinematic_id.is_empty():
		return false

	# Check active mod first
	var local_path: String = cinematics_dir.path_join(cinematic_id + ".tres")
	if FileAccess.file_exists(local_path):
		return true

	# Check all loaded mods via registry
	if ModLoader and ModLoader.registry:
		var cinematic: CinematicData = ModLoader.registry.get_cinematic(cinematic_id)
		if cinematic:
			return true

	return false


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
