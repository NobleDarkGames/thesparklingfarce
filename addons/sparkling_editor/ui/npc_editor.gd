@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## NPC Editor UI
## Allows browsing and editing NPCData resources
##
## NPCs are interactable entities on maps that trigger cinematics when the player
## interacts with them. They can have:
## - Portrait and map spritesheet for appearance
## - Primary interaction cinematic
## - Fallback cinematic
## - Conditional cinematics that trigger based on game flags
##
## Component Architecture:
## - NPCPreviewPanel: Live preview rendering (extracted)
## - MapPlacementHelper: Scene modification for "Place on Map" (extracted)

# UI field references - Basic Information
var npc_id_edit: LineEdit
var npc_id_lock_btn: Button
var npc_name_edit: LineEdit

# Track if ID should auto-generate from name
var _id_is_locked: bool = false

# Appearance Fallback section
var appearance_section: VBoxContainer
var portrait_path_edit: LineEdit
var portrait_preview: TextureRect
var portrait_file_dialog: EditorFileDialog
var map_spritesheet_picker: MapSpritesheetPicker

# Interaction section - using ResourcePicker for mod-aware cinematic selection
var interaction_cinematic_picker: ResourcePicker
var interaction_warning: Label
var fallback_cinematic_picker: ResourcePicker
var fallback_warning: Label

# Conditional cinematics section
var conditionals_container: VBoxContainer
var add_conditional_btn: Button

# Behavior section
var face_player_check: CheckBox
var facing_override_option: OptionButton

# Advanced options section (collapsible)
var advanced_section: VBoxContainer
var advanced_toggle_btn: Button
var advanced_content: VBoxContainer

# Place on Map section
var place_on_map_btn: Button
var map_selection_popup: PopupPanel
var map_list: ItemList
var place_confirm_btn: Button
var place_position_x: SpinBox
var place_position_y: SpinBox

# Extracted Components
var preview_panel: NPCPreviewPanel
var map_placement_helper: MapPlacementHelper

# Track conditional entries for dynamic UI
var conditional_entries: Array[Dictionary] = []

# Flag to prevent signal feedback loops during UI updates
var _updating_ui: bool = false


func _ready() -> void:
	resource_type_name = "NPC"
	resource_type_id = "npc"
	# Declare dependencies BEFORE super._ready() so base class can auto-subscribe
	resource_dependencies = ["cinematic"]  # For cinematic pickers
	super._ready()

	# Initialize helper components
	map_placement_helper = MapPlacementHelper.new()


## Handle dependency changes - refresh cinematic pickers when cinematics change
func _on_dependencies_changed(changed_type: String) -> void:
	if changed_type == "cinematic":
		# Refresh main cinematic pickers
		if interaction_cinematic_picker:
			interaction_cinematic_picker.refresh()
		if fallback_cinematic_picker:
			fallback_cinematic_picker.refresh()
		# Refresh conditional cinematic pickers
		for entry: Dictionary in conditional_entries:
			var picker: ResourcePicker = entry.get("cinematic_picker") as ResourcePicker
			if picker:
				picker.refresh()


## Override: Create the NPC-specific detail form
func _create_detail_form() -> void:
	var main_split: HSplitContainer = HSplitContainer.new()
	main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Left side: Form content
	var form_container: VBoxContainer = VBoxContainer.new()
	form_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_container.custom_minimum_size.x = 350  # Reduced from 400 for better laptop support

	# Right side: Preview panel (using extracted component)
	preview_panel = NPCPreviewPanel.new()

	main_split.add_child(form_container)
	main_split.add_child(preview_panel)

	detail_panel.add_child(main_split)

	# Store reference to form container for adding sections
	var original_detail_panel: Control = detail_panel
	detail_panel = form_container

	_add_basic_info_section()
	_add_appearance_fallback_section()
	_add_place_on_map_section()
	_add_advanced_options_section()

	# Bind preview panel to data sources
	# Note: sprite_path is null since we now use MapSpritesheetPicker (which has its own preview)
	# Note: dialog_text is null since Quick Dialog was removed - preview shows name/portrait only
	preview_panel.bind_sources(npc_name_edit, null, null, portrait_path_edit, null)

	detail_panel = original_detail_panel
	form_container.add_child(button_container)


## Override: Load NPC data from resource into UI
func _load_resource_data() -> void:
	if not current_resource is NPCData:
		return
	var npc: NPCData = current_resource

	_updating_ui = true

	npc_name_edit.text = npc.npc_name
	npc_id_edit.text = npc.npc_id

	var expected_auto_id: String = SparklingEditorUtils.generate_id_from_name(npc.npc_name)
	_id_is_locked = (npc.npc_id != expected_auto_id) and not npc.npc_id.is_empty()
	_update_lock_button()

	var portrait_path: String = npc.portrait.resource_path if npc.portrait else ""
	portrait_path_edit.text = portrait_path
	_load_portrait_preview(portrait_path)

	# Load sprite_frames using MapSpritesheetPicker
	if map_spritesheet_picker:
		map_spritesheet_picker.load_from_sprite_frames(npc.sprite_frames)

	# Load cinematics using ResourcePicker (deferred to ensure pickers are ready)
	if interaction_cinematic_picker:
		if npc.interaction_cinematic_id.is_empty():
			interaction_cinematic_picker.call_deferred("select_none")
		else:
			interaction_cinematic_picker.call_deferred("select_by_id", "", npc.interaction_cinematic_id)
	if fallback_cinematic_picker:
		if npc.fallback_cinematic_id.is_empty():
			fallback_cinematic_picker.call_deferred("select_none")
		else:
			fallback_cinematic_picker.call_deferred("select_by_id", "", npc.fallback_cinematic_id)

	_load_conditional_cinematics(npc.conditional_cinematics)

	face_player_check.button_pressed = npc.face_player_on_interact
	_set_facing_dropdown(npc.facing_override)

	_updating_ui = false

	call_deferred("_update_preview")


## Override: Save UI data to resource
func _save_resource_data() -> void:
	if not current_resource is NPCData:
		return
	var npc: NPCData = current_resource

	npc.npc_id = npc_id_edit.text.strip_edges()
	npc.npc_name = npc_name_edit.text.strip_edges()

	var portrait_path: String = portrait_path_edit.text.strip_edges()
	npc.portrait = _load_texture(portrait_path)

	# Save sprite_frames from MapSpritesheetPicker
	if map_spritesheet_picker:
		var output_path: String = _generate_sprite_frames_path(npc)
		npc.sprite_frames = map_spritesheet_picker.get_or_generate_sprite_frames(output_path)

	# Save cinematics from ResourcePickers
	npc.interaction_cinematic_id = interaction_cinematic_picker.get_selected_resource_id() if interaction_cinematic_picker else ""
	npc.fallback_cinematic_id = fallback_cinematic_picker.get_selected_resource_id() if fallback_cinematic_picker else ""
	npc.conditional_cinematics = _collect_conditional_cinematics()
	npc.face_player_on_interact = face_player_check.button_pressed
	npc.facing_override = _get_facing_from_dropdown()


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	var npc_id: String = npc_id_edit.text.strip_edges()
	if npc_id.is_empty():
		errors.append("NPC ID is required")

	# Get cinematic IDs from pickers (ResourcePicker validates existence via registry)
	var primary_id: String = interaction_cinematic_picker.get_selected_resource_id() if interaction_cinematic_picker else ""
	var fallback_id: String = fallback_cinematic_picker.get_selected_resource_id() if fallback_cinematic_picker else ""
	var has_primary: bool = not primary_id.is_empty()
	var has_fallback: bool = not fallback_id.is_empty()
	var has_conditional: bool = _has_valid_conditional()

	# Warn if NPC has no dialog configured
	if not has_primary and not has_fallback and not has_conditional:
		warnings.append("NPC has no cinematic - interacting will do nothing")

	# Note: ResourcePicker only shows valid cinematics from the registry,
	# so we don't need to validate existence here

	for i: int in range(conditional_entries.size()):
		var entry: Dictionary = conditional_entries[i]
		var and_val: Variant = entry.get("and_flags_edit")
		var and_flags_edit: LineEdit = and_val if and_val is LineEdit else null
		var or_val: Variant = entry.get("or_flags_edit")
		var or_flags_edit: LineEdit = or_val if or_val is LineEdit else null
		var picker_val: Variant = entry.get("cinematic_picker")
		var cinematic_picker: ResourcePicker = picker_val if picker_val is ResourcePicker else null

		var and_text: String = and_flags_edit.text.strip_edges() if and_flags_edit else ""
		var or_text: String = or_flags_edit.text.strip_edges() if or_flags_edit else ""
		var cine_id: String = cinematic_picker.get_selected_resource_id() if cinematic_picker else ""

		var has_any_flags: bool = not and_text.is_empty() or not or_text.is_empty()
		var has_cinematic: bool = not cine_id.is_empty()

		# Validate: must have either both (flags and cinematic) or neither
		if has_any_flags and not has_cinematic:
			errors.append("Conditional entry %d: Cinematic is required when flags are specified" % (i + 1))
		elif has_cinematic and not has_any_flags:
			errors.append("Conditional entry %d: At least one flag (ALL of or ANY of) is required" % (i + 1))

	return {valid = errors.is_empty(), errors = errors, warnings = warnings}


## Default placeholder paths in core (always available)
const DEFAULT_NPC_SPRITESHEET: String = "res://core/assets/defaults/sprites/default_npc_spritesheet.png"
const DEFAULT_NPC_PORTRAIT: String = "res://core/assets/defaults/default_npc_portrait.png"


## Override: Create a new NPC with defaults
func _create_new_resource() -> Resource:
	var new_npc: NPCData = NPCData.new()
	new_npc.npc_id = "new_npc"
	new_npc.npc_name = "New NPC"
	new_npc.face_player_on_interact = true
	new_npc.facing_override = ""
	new_npc.interaction_cinematic_id = ""
	new_npc.fallback_cinematic_id = ""
	# Note: conditional_cinematics defaults to empty Array[Dictionary] - don't reassign

	# Set default placeholder portrait (from core, always available)
	if ResourceLoader.exists(DEFAULT_NPC_PORTRAIT):
		new_npc.portrait = _load_texture(DEFAULT_NPC_PORTRAIT)

	# Note: sprite_frames will be set by MapSpritesheetPicker when user selects a spritesheet
	# Default NPC spritesheet is applied at runtime by NPCNode if no sprite_frames set

	return new_npc


## Override: Get the display name from an NPC resource
func _get_resource_display_name(resource: Resource) -> String:
	if resource is NPCData:
		var npc: NPCData = resource
		if not npc.npc_name.is_empty():
			return npc.npc_name
		if not npc.npc_id.is_empty():
			return npc.npc_id
	return "Unnamed NPC"


# =============================================================================
# Section Creation Methods
# =============================================================================

func _add_basic_info_section() -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Basic Information", detail_panel)

	# NPC Name
	var name_row: HBoxContainer = SparklingEditorUtils.create_field_row("Display Name:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	npc_name_edit = LineEdit.new()
	npc_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	npc_name_edit.max_length = 64  # Reasonable limit for dialog box display
	npc_name_edit.placeholder_text = "Guard, Shopkeeper, Elder..."
	npc_name_edit.tooltip_text = "Name shown in dialog boxes when this NPC speaks. E.g., 'Guard', 'Old Man', 'Sarah'."
	npc_name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(npc_name_edit)

	# NPC ID
	var id_row: HBoxContainer = SparklingEditorUtils.create_field_row("NPC ID:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	npc_id_edit = LineEdit.new()
	npc_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	npc_id_edit.placeholder_text = "(auto-generated from name)"
	npc_id_edit.tooltip_text = "Unique ID for referencing this NPC in scripts and triggers. Auto-generates from name."
	npc_id_edit.text_changed.connect(_on_id_manually_changed)
	id_row.add_child(npc_id_edit)

	npc_id_lock_btn = Button.new()
	npc_id_lock_btn.text = "Lock"
	npc_id_lock_btn.tooltip_text = "Click to lock ID and prevent auto-generation"
	npc_id_lock_btn.custom_minimum_size.x = 60
	npc_id_lock_btn.pressed.connect(_on_id_lock_toggled)
	id_row.add_child(npc_id_lock_btn)

	SparklingEditorUtils.create_help_label("ID auto-generates from name. Click lock to set custom ID.", section)




func _add_appearance_fallback_section() -> void:
	## Add appearance fallback section to the main detail panel
	_add_appearance_fallback_section_to(detail_panel)


func _add_appearance_fallback_section_to(parent: Control) -> void:
	appearance_section = SparklingEditorUtils.create_section("Appearance", parent)

	# Portrait row with preview and browse button
	var portrait_row: HBoxContainer = SparklingEditorUtils.create_field_row("Portrait:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, appearance_section)

	# Preview at 32x32
	var portrait_preview_panel: PanelContainer = PanelContainer.new()
	portrait_preview_panel.custom_minimum_size = Vector2(36, 36)
	var portrait_style: StyleBoxFlat = StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	portrait_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	portrait_style.set_border_width_all(1)
	portrait_style.set_content_margin_all(2)
	portrait_preview_panel.add_theme_stylebox_override("panel", portrait_style)

	portrait_preview = TextureRect.new()
	portrait_preview.custom_minimum_size = Vector2(32, 32)
	portrait_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_preview_panel.add_child(portrait_preview)
	portrait_row.add_child(portrait_preview_panel)

	portrait_path_edit = LineEdit.new()
	portrait_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_path_edit.placeholder_text = "res://mods/<mod>/assets/portraits/npc.png"
	portrait_path_edit.text_changed.connect(_on_portrait_path_changed)
	portrait_row.add_child(portrait_path_edit)

	var portrait_browse_btn: Button = Button.new()
	portrait_browse_btn.text = "Browse..."
	portrait_browse_btn.pressed.connect(_on_browse_portrait)
	portrait_row.add_child(portrait_browse_btn)

	var portrait_clear_btn: Button = Button.new()
	portrait_clear_btn.text = "X"
	portrait_clear_btn.tooltip_text = "Clear portrait"
	portrait_clear_btn.pressed.connect(_on_clear_portrait)
	portrait_row.add_child(portrait_clear_btn)

	# Map Spritesheet picker (animated walk cycle)
	map_spritesheet_picker = MapSpritesheetPicker.new()
	map_spritesheet_picker.label_text = "Map Spritesheet:"
	map_spritesheet_picker.texture_selected.connect(_on_spritesheet_selected)
	map_spritesheet_picker.sprite_frames_generated.connect(_on_sprite_frames_generated)
	appearance_section.add_child(map_spritesheet_picker)

	SparklingEditorUtils.create_help_label("64x128 spritesheet with 4 directions × 2 frames", appearance_section)


func _add_place_on_map_section() -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Place on Map", detail_panel)

	var pos_row: HBoxContainer = SparklingEditorUtils.create_field_row("Grid Position:", 100, section)
	var x_label: Label = Label.new()
	x_label.text = "X:"
	pos_row.add_child(x_label)

	place_position_x = SpinBox.new()
	place_position_x.min_value = -100
	place_position_x.max_value = 100
	place_position_x.value = 5
	place_position_x.custom_minimum_size.x = 70
	place_position_x.tooltip_text = "X grid coordinate where NPC will be placed on the map."
	pos_row.add_child(place_position_x)

	var y_label: Label = Label.new()
	y_label.text = "Y:"
	pos_row.add_child(y_label)

	place_position_y = SpinBox.new()
	place_position_y.min_value = -100
	place_position_y.max_value = 100
	place_position_y.value = 5
	place_position_y.custom_minimum_size.x = 70
	place_position_y.tooltip_text = "Y grid coordinate where NPC will be placed on the map."
	pos_row.add_child(place_position_y)

	place_on_map_btn = Button.new()
	place_on_map_btn.text = "Place on Map..."
	place_on_map_btn.tooltip_text = "Add this NPC to a map in the current mod"
	place_on_map_btn.pressed.connect(_on_place_on_map_pressed)
	section.add_child(place_on_map_btn)

	SparklingEditorUtils.create_help_label("Save the NPC first, then click to add it to a map", section)
	_create_map_selection_popup()


func _create_map_selection_popup() -> void:
	map_selection_popup = PopupPanel.new()
	map_selection_popup.title = "Select Map"

	var popup_content: VBoxContainer = VBoxContainer.new()
	popup_content.custom_minimum_size = Vector2(400, 300)

	var popup_label: Label = Label.new()
	popup_label.text = "Select a map to place the NPC on:"
	popup_content.add_child(popup_label)

	map_list = ItemList.new()
	map_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_list.custom_minimum_size.y = 200
	map_list.item_activated.connect(_on_map_double_clicked)
	popup_content.add_child(map_list)

	var btn_container: HBoxContainer = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_END

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): map_selection_popup.hide())
	btn_container.add_child(cancel_btn)

	place_confirm_btn = Button.new()
	place_confirm_btn.text = "Place NPC"
	place_confirm_btn.pressed.connect(_on_place_confirmed)
	btn_container.add_child(place_confirm_btn)

	popup_content.add_child(btn_container)
	map_selection_popup.add_child(popup_content)
	add_child(map_selection_popup)


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

	_add_interaction_section_to(advanced_content)
	_add_conditional_cinematics_section_to(advanced_content)
	_add_behavior_section_to(advanced_content)

	detail_panel.add_child(advanced_section)


func _on_advanced_toggle() -> void:
	advanced_content.visible = not advanced_content.visible
	advanced_toggle_btn.text = "Advanced Options (expanded)" if advanced_content.visible else "Advanced Options"


func _add_interaction_section_to(parent: Control) -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Cinematic Assignment", parent)

	var primary_row: HBoxContainer = SparklingEditorUtils.create_field_row("Primary Cinematic:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	interaction_cinematic_picker = ResourcePicker.new()
	interaction_cinematic_picker.resource_type = "cinematic"
	interaction_cinematic_picker.allow_none = true
	interaction_cinematic_picker.none_text = "(None)"
	interaction_cinematic_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interaction_cinematic_picker.resource_selected.connect(_on_cinematic_picker_changed.bind("primary"))
	primary_row.add_child(interaction_cinematic_picker)

	interaction_warning = Label.new()
	interaction_warning.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	interaction_warning.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	interaction_warning.visible = false
	section.add_child(interaction_warning)

	SparklingEditorUtils.create_help_label("Default cinematic when player interacts (if no conditionals match)", section)

	var fallback_row: HBoxContainer = SparklingEditorUtils.create_field_row("Fallback Cinematic:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	fallback_cinematic_picker = ResourcePicker.new()
	fallback_cinematic_picker.resource_type = "cinematic"
	fallback_cinematic_picker.allow_none = true
	fallback_cinematic_picker.none_text = "(None)"
	fallback_cinematic_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fallback_cinematic_picker.resource_selected.connect(_on_cinematic_picker_changed.bind("fallback"))
	fallback_row.add_child(fallback_cinematic_picker)

	fallback_warning = Label.new()
	fallback_warning.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	fallback_warning.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	fallback_warning.visible = false
	section.add_child(fallback_warning)

	SparklingEditorUtils.create_help_label("Last resort if no conditions match and no primary cinematic", section)


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

	var face_row: HBoxContainer = SparklingEditorUtils.create_field_row("Face Player:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	face_player_check = CheckBox.new()
	face_player_check.text = "Turn to face player when interaction starts"
	face_player_check.button_pressed = true
	face_player_check.tooltip_text = "NPC rotates to look at the player when spoken to. Turn off for guards staring at walls, etc."
	face_player_check.toggled.connect(_on_check_changed)
	face_row.add_child(face_player_check)

	var facing_row: HBoxContainer = SparklingEditorUtils.create_field_row("Facing Override:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	facing_override_option = OptionButton.new()
	facing_override_option.tooltip_text = "Force NPC to always face a specific direction. (Auto) = faces player or uses sprite default."
	facing_override_option.add_item("(Auto)", 0)
	facing_override_option.add_item("Up", 1)
	facing_override_option.add_item("Down", 2)
	facing_override_option.add_item("Left", 3)
	facing_override_option.add_item("Right", 4)
	facing_override_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facing_override_option.item_selected.connect(_on_option_changed)
	facing_row.add_child(facing_override_option)

	SparklingEditorUtils.create_help_label("Force NPC to always face a specific direction (overrides face player)", section)


# =============================================================================
# Conditional Cinematics UI Management
# =============================================================================

func _load_conditional_cinematics(conditionals: Array[Dictionary]) -> void:
	_clear_conditional_entries()
	for cond: Dictionary in conditionals:
		# Build the AND flags array
		var flags_and: Array = []
		# Legacy single "flag" key gets converted to AND array
		var single_flag: String = DictUtils.get_string(cond, "flag", "")
		if not single_flag.is_empty():
			flags_and.append(single_flag)
		# Add any flags from "flags" array
		var explicit_flags: Array = DictUtils.get_array(cond, "flags", [])
		for flag: String in explicit_flags:
			if not flag.is_empty() and flag not in flags_and:
				flags_and.append(flag)

		# OR flags from "any_flags" array
		var flags_or: Array = DictUtils.get_array(cond, "any_flags", [])

		var negate: bool = DictUtils.get_bool(cond, "negate", false)
		var cinematic_id: String = DictUtils.get_string(cond, "cinematic_id", "")

		_add_conditional_entry(flags_and, flags_or, negate, cinematic_id)


## Add a conditional entry to the UI
## Parameters:
##   flags_and: Array of flag names that must ALL be true (AND logic)
##   flags_or: Array of flag names where at least ONE must be true (OR logic)
##   negate: If true, invert the overall condition result
##   cinematic_id: The cinematic to play when condition is met
func _add_conditional_entry(flags_and: Array = [], flags_or: Array = [], negate: bool = false, cinematic_id: String = "") -> void:
	var entry_container: VBoxContainer = VBoxContainer.new()
	entry_container.add_theme_constant_override("separation", 2)

	# Create a panel for visual grouping
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

	# Row 1: AND flags (all must be true)
	var and_row: HBoxContainer = HBoxContainer.new()
	and_row.add_theme_constant_override("separation", 4)
	panel_content.add_child(and_row)

	var and_label: Label = Label.new()
	and_label.text = "ALL of:"
	and_label.tooltip_text = "All these flags must be set (AND logic)"
	and_label.custom_minimum_size.x = 55
	and_row.add_child(and_label)

	var and_flags_edit: LineEdit = LineEdit.new()
	and_flags_edit.placeholder_text = "flag1, flag2, flag3 (comma-separated)"
	and_flags_edit.text = ", ".join(flags_and) if not flags_and.is_empty() else ""
	and_flags_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	and_flags_edit.tooltip_text = "Enter flag names separated by commas. ALL must be set for condition to match."
	and_flags_edit.text_changed.connect(_on_field_changed)
	and_row.add_child(and_flags_edit)

	# Row 2: OR flags (at least one must be true)
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

	# Row 3: Cinematic picker and controls
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

	var cinematic_picker: ResourcePicker = ResourcePicker.new()
	cinematic_picker.resource_type = "cinematic"
	cinematic_picker.allow_none = true
	cinematic_picker.none_text = "(None)"
	cinematic_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cinematic_picker.tooltip_text = "The cinematic to play when this condition is met"
	cinematic_picker.resource_selected.connect(_on_conditional_cinematic_changed)
	cinematic_row.add_child(cinematic_picker)

	# Set initial value if provided (deferred to ensure picker is ready)
	if not cinematic_id.is_empty():
		cinematic_picker.call_deferred("select_by_id", "", cinematic_id)

	var remove_btn: Button = Button.new()
	remove_btn.text = "X"
	remove_btn.tooltip_text = "Remove this condition"
	remove_btn.custom_minimum_size.x = 30
	remove_btn.pressed.connect(_on_remove_conditional.bind(entry_container))
	cinematic_row.add_child(remove_btn)

	conditionals_container.add_child(entry_container)
	conditional_entries.append({
		"container": entry_container,
		"and_flags_edit": and_flags_edit,
		"or_flags_edit": or_flags_edit,
		"negate_check": negate_check,
		"cinematic_picker": cinematic_picker
	})


func _clear_conditional_entries() -> void:
	for entry: Dictionary in conditional_entries:
		var container_val: Variant = entry.get("container")
		var container: Control = container_val if container_val is Control else null
		if container and is_instance_valid(container):
			container.queue_free()
	conditional_entries.clear()


func _collect_conditional_cinematics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in conditional_entries:
		var and_val: Variant = entry.get("and_flags_edit")
		var and_flags_edit: LineEdit = and_val if and_val is LineEdit else null
		var or_val: Variant = entry.get("or_flags_edit")
		var or_flags_edit: LineEdit = or_val if or_val is LineEdit else null
		var negate_val: Variant = entry.get("negate_check")
		var negate_check: CheckBox = negate_val if negate_val is CheckBox else null
		var picker_val: Variant = entry.get("cinematic_picker")
		var cinematic_picker: ResourcePicker = picker_val if picker_val is ResourcePicker else null

		# Get cinematic ID from picker
		var cine_id: String = cinematic_picker.get_selected_resource_id() if cinematic_picker else ""

		# Parse AND flags (comma-separated)
		var and_flags: Array[String] = []
		if and_flags_edit:
			var and_text: String = and_flags_edit.text.strip_edges()
			if not and_text.is_empty():
				for flag: String in and_text.split(","):
					var clean_flag: String = flag.strip_edges()
					if not clean_flag.is_empty():
						and_flags.append(clean_flag)

		# Parse OR flags (comma-separated)
		var or_flags: Array[String] = []
		if or_flags_edit:
			var or_text: String = or_flags_edit.text.strip_edges()
			if not or_text.is_empty():
				for flag: String in or_text.split(","):
					var clean_flag: String = flag.strip_edges()
					if not clean_flag.is_empty():
						or_flags.append(clean_flag)

		# Skip entries with no flags and no cinematic
		if and_flags.is_empty() and or_flags.is_empty() and cine_id.is_empty():
			continue

		# Build the condition dictionary
		var cond_dict: Dictionary = {"cinematic_id": cine_id}

		# Use "flags" array for AND logic (new format)
		if not and_flags.is_empty():
			cond_dict["flags"] = and_flags

		# Use "any_flags" array for OR logic
		if not or_flags.is_empty():
			cond_dict["any_flags"] = or_flags

		if negate_check and negate_check.button_pressed:
			cond_dict["negate"] = true

		result.append(cond_dict)
	return result


func _has_valid_conditional() -> bool:
	for entry: Dictionary in conditional_entries:
		var and_val: Variant = entry.get("and_flags_edit")
		var and_flags_edit: LineEdit = and_val if and_val is LineEdit else null
		var or_val: Variant = entry.get("or_flags_edit")
		var or_flags_edit: LineEdit = or_val if or_val is LineEdit else null
		var picker_val: Variant = entry.get("cinematic_picker")
		var cinematic_picker: ResourcePicker = picker_val if picker_val is ResourcePicker else null

		# Get cinematic ID from picker
		var cine_id: String = cinematic_picker.get_selected_resource_id() if cinematic_picker else ""
		if cine_id.is_empty():
			continue

		# Check if there are any flags defined (AND or OR)
		var has_and_flags: bool = and_flags_edit and not and_flags_edit.text.strip_edges().is_empty()
		var has_or_flags: bool = or_flags_edit and not or_flags_edit.text.strip_edges().is_empty()

		if has_and_flags or has_or_flags:
			return true
	return false


# =============================================================================
# UI Event Handlers
# =============================================================================

func _on_add_conditional() -> void:
	_add_conditional_entry()


func _on_remove_conditional(entry_container: HBoxContainer) -> void:
	for i: int in range(conditional_entries.size()):
		if conditional_entries[i].get("container") == entry_container:
			conditional_entries.remove_at(i)
			break
	entry_container.queue_free()
	_mark_dirty()


func _on_field_changed(_text: String) -> void:
	if _updating_ui:
		return
	_update_preview()
	_mark_dirty()


func _on_name_changed(new_name: String) -> void:
	if _updating_ui:
		return
	if not _id_is_locked:
		npc_id_edit.text = SparklingEditorUtils.generate_id_from_name(new_name)
	_update_preview()
	_mark_dirty()


func _on_id_manually_changed(_text: String) -> void:
	if _updating_ui:
		return
	if not _id_is_locked and npc_id_edit.has_focus():
		_id_is_locked = true
		_update_lock_button()
	_mark_dirty()


func _on_id_lock_toggled() -> void:
	_id_is_locked = not _id_is_locked
	_update_lock_button()
	if not _id_is_locked:
		npc_id_edit.text = SparklingEditorUtils.generate_id_from_name(npc_name_edit.text)


func _update_lock_button() -> void:
	npc_id_lock_btn.text = "Unlock" if _id_is_locked else "Lock"
	npc_id_lock_btn.tooltip_text = "ID is locked. Click to unlock and auto-generate." if _id_is_locked else "Click to lock ID and prevent auto-generation"


func _on_check_changed(_pressed: bool) -> void:
	if _updating_ui:
		return
	_mark_dirty()


func _on_option_changed(_index: int) -> void:
	if _updating_ui:
		return
	_mark_dirty()


## Called when primary or fallback cinematic picker selection changes
func _on_cinematic_picker_changed(_metadata: Dictionary, _field_type: String) -> void:
	if _updating_ui:
		return
	# ResourcePicker only shows valid cinematics, so no validation warnings needed
	# Hide any legacy warnings
	if interaction_warning:
		interaction_warning.visible = false
	if fallback_warning:
		fallback_warning.visible = false
	_mark_dirty()


## Called when a conditional cinematic picker selection changes
func _on_conditional_cinematic_changed(_metadata: Dictionary) -> void:
	if _updating_ui:
		return
	_mark_dirty()


# =============================================================================
# Place on Map (using MapPlacementHelper)
# =============================================================================

func _on_place_on_map_pressed() -> void:
	if not current_resource:
		_show_error("No NPC selected.")
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
			var npc_id: String = npc_id_edit.text.strip_edges()
			var filename: String = npc_id + ".tres" if not npc_id.is_empty() else "new_npc_%d.tres" % Time.get_unix_time_from_system()
			save_path = save_dir.path_join(filename)

		var err: Error = ResourceSaver.save(current_resource, save_path)
		if err != OK:
			_show_error("Failed to save NPC: " + str(err))
			return

		# Update resource path and clear dirty flag
		current_resource.take_over_path(save_path)
		current_resource_path = save_path
		is_dirty = false
		_hide_errors()
		_refresh_list()

	_populate_map_list()
	map_selection_popup.popup_centered()


func _populate_map_list() -> void:
	if not map_list:
		return
	map_list.clear()
	var mod_path: String = SparklingEditorUtils.get_active_mod_path()
	if mod_path.is_empty():
		map_list.add_item("(No active mod selected)")
		return
	var maps: Array[Dictionary] = MapPlacementHelper.get_available_maps(mod_path)
	if maps.is_empty():
		map_list.add_item("(No maps found)")
		return
	for map_info: Dictionary in maps:
		var display_name: String = DictUtils.get_string(map_info, "display_name", "Unknown")
		var map_path: String = DictUtils.get_string(map_info, "path", "")
		map_list.add_item(display_name)
		map_list.set_item_metadata(map_list.item_count - 1, map_path)


func _on_map_double_clicked(index: int) -> void:
	map_list.select(index)
	_on_place_confirmed()


func _on_place_confirmed() -> void:
	if not map_list:
		return
	var selected_items: PackedInt32Array = map_list.get_selected_items()
	if selected_items.is_empty():
		_show_error("Please select a map first.")
		return
	var selected_index: int = selected_items[0]
	var map_path: String = map_list.get_item_metadata(selected_index)
	if map_path.is_empty() or not FileAccess.file_exists(map_path):
		_show_error("Invalid map selection.")
		return

	var npc_path: String = current_resource.resource_path
	var grid_x: int = int(place_position_x.value)
	var grid_y: int = int(place_position_y.value)
	var npc_id: String = npc_id_edit.text.strip_edges()
	var node_name: String = npc_id.to_pascal_case() if not npc_id.is_empty() else "NPC"

	var success: bool = map_placement_helper.place_npc_on_map(map_path, npc_path, node_name, Vector2i(grid_x, grid_y))
	if success:
		map_selection_popup.hide()
	else:
		_show_error("Failed to place NPC on map. Check the output for details.")


# =============================================================================
# Helper Functions
# =============================================================================

func _update_preview() -> void:
	if preview_panel:
		preview_panel.update_preview()


func _get_active_mod_cinematics_path() -> String:
	var mod_path: String = SparklingEditorUtils.get_active_mod_path()
	if mod_path.is_empty():
		return ""
	return mod_path.path_join("data/cinematics/")


func _set_facing_dropdown(facing: String) -> void:
	if not facing_override_option:
		return
	var facing_index: int = 0
	match facing:
		"up": facing_index = 1
		"down": facing_index = 2
		"left": facing_index = 3
		"right": facing_index = 4
	facing_override_option.select(facing_index)


func _get_facing_from_dropdown() -> String:
	if not facing_override_option:
		return ""
	match facing_override_option.selected:
		1: return "up"
		2: return "down"
		3: return "left"
		4: return "right"
	return ""


## Generate a unique path for NPC's sprite_frames resource
## Format: res://mods/<mod>/data/sprite_frames/npc_<npc_id>_map_sprites.tres
func _generate_sprite_frames_path(npc: NPCData) -> String:
	var mod_path: String = SparklingEditorUtils.get_active_mod_path()
	if mod_path.is_empty():
		mod_path = "res://mods/_sandbox"

	var sprite_frames_dir: String = mod_path.path_join("data/sprite_frames/")
	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(sprite_frames_dir):
		DirAccess.make_dir_recursive_absolute(sprite_frames_dir)

	var npc_id: String = npc.npc_id if npc and not npc.npc_id.is_empty() else "unnamed_npc"
	return sprite_frames_dir.path_join("npc_%s_map_sprites.tres" % npc_id)


# =============================================================================
# Portrait and Sprite Browse Functions
# =============================================================================

func _on_browse_portrait() -> void:
	if not portrait_file_dialog:
		portrait_file_dialog = EditorFileDialog.new()
		portrait_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		portrait_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		portrait_file_dialog.filters = PackedStringArray(["*.png ; PNG Images", "*.webp ; WebP Images", "*.jpg ; JPEG Images"])
		# Safety check before connecting (prevents duplicates on plugin reload)
		if not portrait_file_dialog.file_selected.is_connected(_on_portrait_file_selected):
			portrait_file_dialog.file_selected.connect(_on_portrait_file_selected)
		add_child(portrait_file_dialog)

	# Default to active mod's portraits directory if available
	var default_path: String = _get_default_asset_path("portraits")
	portrait_file_dialog.current_dir = default_path
	portrait_file_dialog.popup_centered_ratio(0.7)


func _on_portrait_file_selected(path: String) -> void:
	portrait_path_edit.text = path
	_load_portrait_preview(path)
	_update_preview()
	_mark_dirty()


func _on_portrait_path_changed(new_text: String) -> void:
	if _updating_ui:
		return
	_load_portrait_preview(new_text)
	_update_preview()
	_mark_dirty()


func _load_portrait_preview(path: String) -> void:
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty():
		portrait_preview.texture = null
		portrait_preview.tooltip_text = "No portrait assigned"
		return

	if ResourceLoader.exists(clean_path):
		var loaded: Resource = load(clean_path)
		var texture: Texture2D = loaded if loaded is Texture2D else null
		portrait_preview.texture = texture
		portrait_preview.tooltip_text = clean_path
	else:
		portrait_preview.texture = null
		portrait_preview.tooltip_text = "File not found: " + clean_path


func _on_clear_portrait() -> void:
	portrait_path_edit.text = ""
	portrait_preview.texture = null
	portrait_preview.tooltip_text = "No portrait assigned"
	_update_preview()
	_mark_dirty()


## Called when a spritesheet is selected in the MapSpritesheetPicker
func _on_spritesheet_selected(_path: String, _texture: Texture2D) -> void:
	if _updating_ui:
		return
	_update_preview()
	_mark_dirty()


## Called when SpriteFrames are generated from the selected spritesheet
func _on_sprite_frames_generated(_sprite_frames: SpriteFrames) -> void:
	if _updating_ui:
		return
	_update_preview()
	_mark_dirty()


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


## Helper to safely load a texture from path
func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded: Resource = load(path)
	return loaded if loaded is Texture2D else null
