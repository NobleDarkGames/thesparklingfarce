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
var name_id_group: NameIdFieldGroup

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
var conditionals_list: DynamicRowList

# Behavior section
var face_player_check: CheckBox
var facing_override_option: OptionButton

# Ambient Patrol section
var ambient_cinematic_picker: ResourcePicker

# Advanced options section (collapsible)
var advanced_section: VBoxContainer
var advanced_toggle_btn: Button
var advanced_content: VBoxContainer

# Place on Map section
var place_on_map_btn: Button
var place_position_x: SpinBox
var place_position_y: SpinBox
var place_on_map_dialog: PlaceOnMapDialog

# Extracted Components
var preview_panel: NPCPreviewPanel
var map_placement_helper: MapPlacementHelper



func _ready() -> void:
	resource_type_name = "NPC"
	resource_type_id = "npc"
	# Declare dependencies BEFORE super._ready() so base class can auto-subscribe
	# Note: "cinematics" (plural) matches cinematic_editor.resource_dir_name
	resource_dependencies = ["cinematics"]  # For cinematic pickers
	super._ready()

	# Initialize helper components
	map_placement_helper = MapPlacementHelper.new()


## Handle dependency changes - refresh cinematic pickers when cinematics change
func _on_dependencies_changed(changed_type: String) -> void:
	if changed_type == "cinematics":
		# Refresh main cinematic pickers
		if interaction_cinematic_picker:
			interaction_cinematic_picker.refresh()
		if fallback_cinematic_picker:
			fallback_cinematic_picker.refresh()
		if ambient_cinematic_picker:
			ambient_cinematic_picker.refresh()
		# Refresh conditional cinematic pickers using shared component
		ConditionalCinematicsRowFactory.refresh_pickers_in_list(conditionals_list)


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
	preview_panel.bind_sources(name_id_group.get_name_edit(), null, null, portrait_path_edit, null)

	detail_panel = original_detail_panel
	form_container.add_child(button_container)


## Override: Load NPC data from resource into UI
func _load_resource_data() -> void:
	if not current_resource is NPCData:
		return
	var npc: NPCData = current_resource

	_updating_ui = true

	# Load name/ID using component (auto-detects lock state)
	name_id_group.set_values(npc.npc_name, npc.npc_id, true)

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

	# Load ambient patrol cinematic
	if ambient_cinematic_picker:
		if npc.ambient_cinematic_id.is_empty():
			ambient_cinematic_picker.call_deferred("select_none")
		else:
			ambient_cinematic_picker.call_deferred("select_by_id", "", npc.ambient_cinematic_id)

	_updating_ui = false

	call_deferred("_update_preview")


## Override: Save UI data to resource
func _save_resource_data() -> void:
	if not current_resource is NPCData:
		return
	var npc: NPCData = current_resource

	npc.npc_id = name_id_group.get_id_value()
	npc.npc_name = name_id_group.get_name_value()

	var portrait_path: String = portrait_path_edit.text.strip_edges()
	npc.portrait = SparklingEditorUtils.load_texture(portrait_path)

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

	# Save ambient patrol cinematic
	npc.ambient_cinematic_id = ambient_cinematic_picker.get_selected_resource_id() if ambient_cinematic_picker else ""


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	var npc_id: String = name_id_group.get_id_value()
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

	var conditional_data: Array[Dictionary] = conditionals_list.get_all_data()
	for i: int in range(conditional_data.size()):
		var entry: Dictionary = conditional_data[i]
		var and_text: String = entry.get("and_flags", "")
		var or_text: String = entry.get("or_flags", "")
		var cine_id: String = entry.get("cinematic_id", "")

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
		new_npc.portrait = SparklingEditorUtils.load_texture(DEFAULT_NPC_PORTRAIT)

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

	# Name/ID using reusable component
	name_id_group = NameIdFieldGroup.new()
	name_id_group.name_label = "Display Name:"
	name_id_group.id_label = "NPC ID:"
	name_id_group.name_placeholder = "Guard, Shopkeeper, Elder..."
	name_id_group.id_placeholder = "(auto-generated from name)"
	name_id_group.name_tooltip = "Name shown in dialog boxes when this NPC speaks. E.g., 'Guard', 'Old Man', 'Sarah'."
	name_id_group.id_tooltip = "Unique ID for referencing this NPC in scripts and triggers. Auto-generates from name."
	name_id_group.name_max_length = 64
	name_id_group.label_width = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	name_id_group.value_changed.connect(_on_name_id_changed)
	section.add_child(name_id_group)




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

	# Create the map selection dialog component
	place_on_map_dialog = PlaceOnMapDialog.new()
	place_on_map_dialog.setup(self, "NPC")
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

	SparklingEditorUtils.create_help_label("Conditions checked in order. First matching condition's cinematic plays.", section)

	# Use DynamicRowList for conditional cinematics with shared factory component
	conditionals_list = DynamicRowList.new()
	conditionals_list.add_button_text = "+ Add Condition"
	conditionals_list.add_button_tooltip = "Add a new conditional cinematic that triggers based on game flags."
	conditionals_list.use_scroll_container = true
	conditionals_list.scroll_min_height = 120
	conditionals_list.row_factory = ConditionalCinematicsRowFactory.create_row
	conditionals_list.data_extractor = ConditionalCinematicsRowFactory.extract_data
	conditionals_list.data_changed.connect(_on_conditional_data_changed)
	section.add_child(conditionals_list)


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

	# Ambient Patrol section
	var patrol_section: VBoxContainer = SparklingEditorUtils.create_section("Ambient Patrol", parent)

	var ambient_row: HBoxContainer = SparklingEditorUtils.create_field_row("Patrol Cinematic:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, patrol_section)
	ambient_cinematic_picker = ResourcePicker.new()
	ambient_cinematic_picker.resource_type = "cinematic"
	ambient_cinematic_picker.allow_none = true
	ambient_cinematic_picker.none_text = "(None - stationary)"
	ambient_cinematic_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ambient_cinematic_picker.tooltip_text = "Cinematic that plays automatically on map load. Set loop=true in the cinematic for continuous patrol."
	ambient_cinematic_picker.resource_selected.connect(_on_cinematic_picker_changed.bind("ambient"))
	ambient_row.add_child(ambient_cinematic_picker)

	SparklingEditorUtils.create_help_label("Auto-plays on map load. Use loop=true + move_entity/wait commands. Pauses during interaction.", patrol_section)


# =============================================================================
# Conditional Cinematics - DynamicRowList Factory/Extractor Pattern
# =============================================================================

func _load_conditional_cinematics(conditionals: Array[Dictionary]) -> void:
	# Parse and load into DynamicRowList using shared component
	var conditional_data: Array[Dictionary] = ConditionalCinematicsRowFactory.parse_conditionals_for_loading(conditionals)
	conditionals_list.load_data(conditional_data)


## Called when conditional data changes via DynamicRowList
func _on_conditional_data_changed() -> void:
	if not _updating_ui:
		_mark_dirty()


func _collect_conditional_cinematics() -> Array[Dictionary]:
	return conditionals_list.get_all_data()


func _has_valid_conditional() -> bool:
	return ConditionalCinematicsRowFactory.has_valid_conditional(conditionals_list)


# =============================================================================
# UI Event Handlers
# =============================================================================



func _on_field_changed(_value: Variant = null) -> void:
	if _updating_ui:
		return
	_update_preview()
	_mark_dirty()


func _on_name_id_changed(_values: Dictionary) -> void:
	if _updating_ui:
		return
	_update_preview()
	_mark_dirty()


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
			var npc_id: String = name_id_group.get_id_value()
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

	place_on_map_dialog.show_dialog()


## Handle map selection from the PlaceOnMapDialog component
func _on_map_selection_confirmed(map_path: String) -> void:
	var npc_path: String = current_resource.resource_path
	var grid_x: int = int(place_position_x.value)
	var grid_y: int = int(place_position_y.value)
	var npc_id: String = name_id_group.get_id_value()
	var node_name: String = npc_id.to_pascal_case() if not npc_id.is_empty() else "NPC"

	var success: bool = map_placement_helper.place_npc_on_map(map_path, npc_path, node_name, Vector2i(grid_x, grid_y))
	if not success:
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


