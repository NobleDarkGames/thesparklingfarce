@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## NPC Editor UI
## Allows browsing and editing NPCData resources
##
## NPCs are interactable entities on maps that trigger cinematics when the player
## interacts with them. They can have:
## - Optional CharacterData for appearance (portrait, sprite)
## - Primary interaction cinematic
## - Fallback cinematic
## - Conditional cinematics that trigger based on game flags
##
## Component Architecture:
## - NPCPreviewPanel: Live preview rendering (extracted)
## - MapPlacementHelper: Scene modification for "Place on Map" (extracted)
## - QuickDialogGenerator: Cinematic creation from quick dialog (extracted)

# UI field references - Basic Information
var npc_id_edit: LineEdit
var npc_id_lock_btn: Button
var npc_name_edit: LineEdit
var character_picker: ResourcePicker
var template_option: OptionButton

# Track if ID should auto-generate from name
var _id_is_locked: bool = false

# NPC Templates - preset configurations for common NPC types
const NPC_TEMPLATES: Dictionary = {
	"custom": {"label": "Custom NPC", "name": "", "dialog": "", "face_player": true},
	"town_guard": {"label": "Town Guard", "name": "Town Guard", "dialog": "Move along, citizen.\nNo trouble here.", "face_player": true},
	"shopkeeper": {"label": "Shopkeeper", "name": "Shopkeeper", "dialog": "Welcome to my shop!\nTake a look around.", "face_player": true},
	"elder": {"label": "Village Elder", "name": "Elder", "dialog": "Greetings, young one.\nI have lived many years in this village.\nPerhaps I can offer some wisdom.", "face_player": true},
	"villager": {"label": "Villager", "name": "Villager", "dialog": "What a lovely day!\nI hope nothing bad happens.", "face_player": true},
	"innkeeper": {"label": "Innkeeper", "name": "Innkeeper", "dialog": "Welcome, weary traveler!\nWould you like to rest here?", "face_player": true},
	"mysterious": {"label": "Mysterious Figure", "name": "???", "dialog": "...\n...Who are you?", "face_player": false, "facing": "down"},
	"child": {"label": "Child", "name": "Child", "dialog": "Hey mister!\nWanna play?", "face_player": true}
}

# Appearance Fallback section
var appearance_section: VBoxContainer
var portrait_path_edit: LineEdit
var portrait_preview: TextureRect
var portrait_file_dialog: EditorFileDialog
var map_spritesheet_picker: MapSpritesheetPicker

# Quick Dialog section
var quick_dialog_section: VBoxContainer
var quick_dialog_status: Label
var quick_dialog_text: TextEdit
var create_dialog_btn: Button

# Interaction section
var interaction_cinematic_edit: LineEdit
var interaction_warning: Label
var fallback_cinematic_edit: LineEdit
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
var quick_dialog_generator: QuickDialogGenerator

# Track conditional entries for dynamic UI
var conditional_entries: Array[Dictionary] = []

# Flag to prevent signal feedback loops during UI updates
var _updating_ui: bool = false


func _ready() -> void:
	resource_type_name = "NPC"
	resource_type_id = "npc"
	super._ready()

	# Initialize helper components
	map_placement_helper = MapPlacementHelper.new()
	quick_dialog_generator = QuickDialogGenerator.new()

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
	_add_quick_dialog_section()
	_add_place_on_map_section()
	_add_advanced_options_section()

	# Bind preview panel to data sources
	# Note: sprite_path is null since we now use MapSpritesheetPicker (which has its own preview)
	preview_panel.bind_sources(npc_name_edit, quick_dialog_text, character_picker, portrait_path_edit, null)

	detail_panel = original_detail_panel
	form_container.add_child(button_container)


## Override: Load NPC data from resource into UI
func _load_resource_data() -> void:
	var npc: NPCData = current_resource as NPCData
	if not npc:
		return

	_updating_ui = true

	if template_option:
		template_option.select(0)

	npc_name_edit.text = npc.npc_name
	npc_id_edit.text = npc.npc_id

	var expected_auto_id: String = SparklingEditorUtils.generate_id_from_name(npc.npc_name)
	_id_is_locked = (npc.npc_id != expected_auto_id) and not npc.npc_id.is_empty()
	_update_lock_button()

	if npc.character_data:
		character_picker.select_resource(npc.character_data)
	else:
		character_picker.select_none()

	_update_appearance_section_visibility()

	var portrait_path: String = npc.portrait.resource_path if npc.portrait else ""
	portrait_path_edit.text = portrait_path
	_load_portrait_preview(portrait_path)

	# Load sprite_frames using MapSpritesheetPicker
	if map_spritesheet_picker:
		if npc.sprite_frames:
			map_spritesheet_picker.set_existing_sprite_frames(npc.sprite_frames)
		else:
			map_spritesheet_picker.clear()

	interaction_cinematic_edit.text = npc.interaction_cinematic_id
	fallback_cinematic_edit.text = npc.fallback_cinematic_id

	# Load Quick Dialog text using extracted component
	var cinematics_dir: String = _get_active_mod_cinematics_path()
	var dialog_text: String = QuickDialogGenerator.load_dialog_text_from_cinematic(
		cinematics_dir, npc.interaction_cinematic_id, npc.npc_id
	)
	quick_dialog_text.text = dialog_text

	_load_conditional_cinematics(npc.conditional_cinematics)

	face_player_check.button_pressed = npc.face_player_on_interact
	_set_facing_dropdown(npc.facing_override)

	_updating_ui = false

	call_deferred("_update_cinematic_warnings")
	call_deferred("_update_quick_dialog_status")
	call_deferred("_update_preview")


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var npc: NPCData = current_resource as NPCData
	if not npc:
		return

	npc.npc_id = npc_id_edit.text.strip_edges()
	npc.npc_name = npc_name_edit.text.strip_edges()
	npc.character_data = character_picker.get_selected_resource() as CharacterData

	var portrait_path: String = portrait_path_edit.text.strip_edges()
	npc.portrait = load(portrait_path) as Texture2D if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path) else null

	# Save sprite_frames from MapSpritesheetPicker
	if map_spritesheet_picker:
		npc.sprite_frames = map_spritesheet_picker.get_generated_sprite_frames()

	npc.interaction_cinematic_id = interaction_cinematic_edit.text.strip_edges()
	npc.fallback_cinematic_id = fallback_cinematic_edit.text.strip_edges()
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

	var primary_id: String = interaction_cinematic_edit.text.strip_edges()
	var fallback_id: String = fallback_cinematic_edit.text.strip_edges()
	var has_primary: bool = not primary_id.is_empty()
	var has_fallback: bool = not fallback_id.is_empty()
	var has_conditional: bool = _has_valid_conditional()

	# No dialog is now allowed (decorative NPCs, dialog added later, etc.)
	if not has_primary and not has_fallback and not has_conditional:
		warnings.append("NPC has no dialog - interacting will do nothing")

	var cinematics_dir: String = _get_active_mod_cinematics_path()
	if has_primary and not QuickDialogGenerator.cinematic_exists(cinematics_dir, primary_id):
		warnings.append("Primary cinematic '%s' not found in loaded mods" % primary_id)
	if has_fallback and not QuickDialogGenerator.cinematic_exists(cinematics_dir, fallback_id):
		warnings.append("Fallback cinematic '%s' not found in loaded mods" % fallback_id)

	for i in range(conditional_entries.size()):
		var entry: Dictionary = conditional_entries[i]
		var flag_edit: LineEdit = entry.get("flag_edit") as LineEdit
		var cinematic_edit: LineEdit = entry.get("cinematic_edit") as LineEdit
		if flag_edit and cinematic_edit:
			var flag_text: String = flag_edit.text.strip_edges()
			var cine_text: String = cinematic_edit.text.strip_edges()
			if (not flag_text.is_empty() and cine_text.is_empty()) or (flag_text.is_empty() and not cine_text.is_empty()):
				errors.append("Conditional entry %d: Both flag and cinematic ID are required" % (i + 1))
			elif not cine_text.is_empty() and not QuickDialogGenerator.cinematic_exists(cinematics_dir, cine_text):
				warnings.append("Conditional cinematic '%s' not found in loaded mods" % cine_text)

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
	new_npc.conditional_cinematics = []

	# Set default placeholder portrait (from core, always available)
	if ResourceLoader.exists(DEFAULT_NPC_PORTRAIT):
		new_npc.portrait = load(DEFAULT_NPC_PORTRAIT) as Texture2D

	# Note: sprite_frames will be set by MapSpritesheetPicker when user selects a spritesheet
	# Default NPC spritesheet is applied at runtime by NPCNode if no sprite_frames set

	return new_npc


## Override: Get the display name from an NPC resource
func _get_resource_display_name(resource: Resource) -> String:
	var npc: NPCData = resource as NPCData
	if npc:
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

	# Template selector
	var template_row: HBoxContainer = SparklingEditorUtils.create_field_row("Start from:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	template_option = OptionButton.new()
	template_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var idx: int = 0
	for key: String in NPC_TEMPLATES.keys():
		var template: Dictionary = NPC_TEMPLATES[key]
		template_option.add_item(template.get("label", key), idx)
		template_option.set_item_metadata(idx, key)
		idx += 1
	template_option.item_selected.connect(_on_template_selected)
	template_row.add_child(template_option)

	SparklingEditorUtils.create_help_label("Choose a template to pre-fill common NPC types", section)

	# NPC Name
	var name_row: HBoxContainer = SparklingEditorUtils.create_field_row("Display Name:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	npc_name_edit = LineEdit.new()
	npc_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	npc_id_lock_btn.text = "Unlock"
	npc_id_lock_btn.tooltip_text = "Lock ID to prevent auto-generation"
	npc_id_lock_btn.custom_minimum_size.x = 60
	npc_id_lock_btn.pressed.connect(_on_id_lock_toggled)
	id_row.add_child(npc_id_lock_btn)

	SparklingEditorUtils.create_help_label("ID auto-generates from name. Click lock to set custom ID.", section)

	# Character Data picker
	character_picker = ResourcePicker.new()
	character_picker.resource_type = "character"
	character_picker.label_text = "Character Data:"
	character_picker.label_min_width = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	character_picker.allow_none = true
	character_picker.none_text = "(Use fallback appearance)"
	character_picker.tooltip_text = "Link to a character for portrait/sprite. If empty, use manual fallback appearance below."
	character_picker.resource_selected.connect(_on_character_selected)
	section.add_child(character_picker)

	SparklingEditorUtils.create_help_label("If set, portrait and sprite come from the character. Otherwise use fallback below.", section)


func _add_appearance_fallback_section_to(parent: Control) -> void:
	appearance_section = SparklingEditorUtils.create_section("Appearance (Fallback)", parent)
	SparklingEditorUtils.create_help_label("Used when no Character Data is assigned", appearance_section)

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


func _add_quick_dialog_section() -> void:
	quick_dialog_section = SparklingEditorUtils.create_section("What does this NPC say?", detail_panel)

	quick_dialog_status = Label.new()
	quick_dialog_status.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	quick_dialog_status.visible = false
	quick_dialog_section.add_child(quick_dialog_status)

	quick_dialog_text = TextEdit.new()
	quick_dialog_text.placeholder_text = "Welcome to our village!\nFeel free to look around."
	quick_dialog_text.custom_minimum_size.y = 100
	quick_dialog_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_dialog_text.scroll_fit_content_height = true
	quick_dialog_text.tooltip_text = "What the NPC says when interacted with. Each line is a separate dialog box."
	quick_dialog_text.text_changed.connect(_on_quick_dialog_changed)
	quick_dialog_section.add_child(quick_dialog_text)

	create_dialog_btn = Button.new()
	create_dialog_btn.text = "Create Dialog"
	create_dialog_btn.tooltip_text = "Generate a cinematic from this dialog and link it to this NPC"
	create_dialog_btn.pressed.connect(_on_create_dialog_cinematic)
	quick_dialog_section.add_child(create_dialog_btn)

	SparklingEditorUtils.create_help_label("For most NPCs, just type their dialog above and click Create!", quick_dialog_section)


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
	advanced_toggle_btn.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	advanced_toggle_btn.pressed.connect(_on_advanced_toggle)
	advanced_section.add_child(advanced_toggle_btn)

	advanced_content = VBoxContainer.new()
	advanced_content.visible = false
	advanced_section.add_child(advanced_content)

	_add_appearance_fallback_section_to(advanced_content)
	_add_interaction_section_to(advanced_content)
	_add_conditional_cinematics_section_to(advanced_content)
	_add_behavior_section_to(advanced_content)

	detail_panel.add_child(advanced_section)


func _on_advanced_toggle() -> void:
	advanced_content.visible = not advanced_content.visible
	advanced_toggle_btn.text = "Advanced Options (expanded)" if advanced_content.visible else "Advanced Options"


func _add_interaction_section_to(parent: Control) -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Manual Cinematic Assignment", parent)

	var primary_row: HBoxContainer = SparklingEditorUtils.create_field_row("Primary Cinematic:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	interaction_cinematic_edit = LineEdit.new()
	interaction_cinematic_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interaction_cinematic_edit.placeholder_text = "cinematic_id"
	interaction_cinematic_edit.text_changed.connect(_on_cinematic_field_changed.bind("primary"))
	primary_row.add_child(interaction_cinematic_edit)

	interaction_warning = Label.new()
	interaction_warning.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	interaction_warning.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	interaction_warning.visible = false
	section.add_child(interaction_warning)

	SparklingEditorUtils.create_help_label("Default cinematic when player interacts (if no conditionals match)", section)

	var fallback_row: HBoxContainer = SparklingEditorUtils.create_field_row("Fallback Cinematic:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	fallback_cinematic_edit = LineEdit.new()
	fallback_cinematic_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fallback_cinematic_edit.placeholder_text = "fallback_cinematic_id"
	fallback_cinematic_edit.text_changed.connect(_on_cinematic_field_changed.bind("fallback"))
	fallback_row.add_child(fallback_cinematic_edit)

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
		_add_conditional_entry(cond.get("flag", ""), cond.get("negate", false), cond.get("cinematic_id", ""))


func _add_conditional_entry(flag_name: String = "", negate: bool = false, cinematic_id: String = "") -> void:
	var entry_container: HBoxContainer = HBoxContainer.new()
	entry_container.add_theme_constant_override("separation", 4)

	var flag_edit: LineEdit = LineEdit.new()
	flag_edit.placeholder_text = "flag_name"
	flag_edit.text = flag_name
	flag_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flag_edit.custom_minimum_size.x = 120
	flag_edit.text_changed.connect(_on_field_changed)
	entry_container.add_child(flag_edit)

	var negate_check: CheckBox = CheckBox.new()
	negate_check.text = "NOT"
	negate_check.tooltip_text = "Trigger when flag is NOT set"
	negate_check.button_pressed = negate
	negate_check.toggled.connect(_on_check_changed)
	entry_container.add_child(negate_check)

	var arrow: Label = Label.new()
	arrow.text = "->"
	entry_container.add_child(arrow)

	var cinematic_edit: LineEdit = LineEdit.new()
	cinematic_edit.placeholder_text = "cinematic_id"
	cinematic_edit.text = cinematic_id
	cinematic_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cinematic_edit.custom_minimum_size.x = 120
	cinematic_edit.text_changed.connect(_on_field_changed)
	entry_container.add_child(cinematic_edit)

	var remove_btn: Button = Button.new()
	remove_btn.text = "X"
	remove_btn.tooltip_text = "Remove this condition"
	remove_btn.custom_minimum_size.x = 30
	remove_btn.pressed.connect(_on_remove_conditional.bind(entry_container))
	entry_container.add_child(remove_btn)

	conditionals_container.add_child(entry_container)
	conditional_entries.append({"container": entry_container, "flag_edit": flag_edit, "negate_check": negate_check, "cinematic_edit": cinematic_edit})


func _clear_conditional_entries() -> void:
	for entry: Dictionary in conditional_entries:
		var container: Control = entry.get("container") as Control
		if container and is_instance_valid(container):
			container.queue_free()
	conditional_entries.clear()


func _collect_conditional_cinematics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in conditional_entries:
		var flag_edit: LineEdit = entry.get("flag_edit") as LineEdit
		var negate_check: CheckBox = entry.get("negate_check") as CheckBox
		var cinematic_edit: LineEdit = entry.get("cinematic_edit") as LineEdit
		if not flag_edit or not cinematic_edit:
			continue
		var flag_text: String = flag_edit.text.strip_edges()
		var cine_text: String = cinematic_edit.text.strip_edges()
		if flag_text.is_empty() and cine_text.is_empty():
			continue
		var cond_dict: Dictionary = {"flag": flag_text, "cinematic_id": cine_text}
		if negate_check and negate_check.button_pressed:
			cond_dict["negate"] = true
		result.append(cond_dict)
	return result


func _has_valid_conditional() -> bool:
	for entry: Dictionary in conditional_entries:
		var flag_edit: LineEdit = entry.get("flag_edit") as LineEdit
		var cinematic_edit: LineEdit = entry.get("cinematic_edit") as LineEdit
		if flag_edit and cinematic_edit:
			if not flag_edit.text.strip_edges().is_empty() and not cinematic_edit.text.strip_edges().is_empty():
				return true
	return false


# =============================================================================
# UI Event Handlers
# =============================================================================

func _on_add_conditional() -> void:
	_add_conditional_entry()


func _on_remove_conditional(entry_container: HBoxContainer) -> void:
	for i in range(conditional_entries.size()):
		if conditional_entries[i].get("container") == entry_container:
			conditional_entries.remove_at(i)
			break
	entry_container.queue_free()


func _on_character_selected(_metadata: Dictionary) -> void:
	if _updating_ui:
		return
	_update_appearance_section_visibility()
	_update_preview()


func _on_quick_dialog_changed() -> void:
	if _updating_ui:
		return
	_update_preview()


func _update_appearance_section_visibility() -> void:
	var has_character: bool = character_picker.has_selection()
	appearance_section.visible = not has_character


func _on_field_changed(_text: String) -> void:
	if _updating_ui:
		return
	_update_preview()


func _on_name_changed(new_name: String) -> void:
	if _updating_ui:
		return
	if not _id_is_locked:
		npc_id_edit.text = SparklingEditorUtils.generate_id_from_name(new_name)
	_update_preview()


func _on_id_manually_changed(_text: String) -> void:
	if _updating_ui:
		return
	if not _id_is_locked and npc_id_edit.has_focus():
		_id_is_locked = true
		_update_lock_button()


func _on_id_lock_toggled() -> void:
	_id_is_locked = not _id_is_locked
	_update_lock_button()
	if not _id_is_locked:
		npc_id_edit.text = SparklingEditorUtils.generate_id_from_name(npc_name_edit.text)


func _update_lock_button() -> void:
	npc_id_lock_btn.text = "Lock" if _id_is_locked else "Unlock"
	npc_id_lock_btn.tooltip_text = "ID is locked. Click to unlock and auto-generate." if _id_is_locked else "ID auto-generates from name. Click to lock."


func _on_check_changed(_pressed: bool) -> void:
	pass


func _on_option_changed(_index: int) -> void:
	pass


func _on_template_selected(index: int) -> void:
	if _updating_ui:
		return
	var template_key: String = template_option.get_item_metadata(index)
	if template_key.is_empty() or template_key == "custom":
		return
	var template: Dictionary = NPC_TEMPLATES.get(template_key, {})
	if template.is_empty():
		return

	_updating_ui = true
	var template_name: String = template.get("name", "")
	if not template_name.is_empty():
		npc_name_edit.text = template_name
		if not _id_is_locked:
			npc_id_edit.text = SparklingEditorUtils.generate_id_from_name(template_name)
	var template_dialog: String = template.get("dialog", "")
	if not template_dialog.is_empty() and quick_dialog_text:
		quick_dialog_text.text = template_dialog
	if template.has("face_player") and face_player_check:
		face_player_check.button_pressed = template.get("face_player", true)
	if template.has("facing") and facing_override_option:
		_set_facing_dropdown(template.get("facing", ""))
	_updating_ui = false

	_show_quick_dialog_status("Applied '%s' template - customize as needed!" % template.get("label", template_key), Color(0.5, 0.8, 1.0))


func _on_cinematic_field_changed(text: String, field_type: String) -> void:
	if _updating_ui:
		return
	_validate_cinematic_field(text.strip_edges(), field_type)


func _validate_cinematic_field(cinematic_id: String, field_type: String) -> void:
	var warning_label: Label = interaction_warning if field_type == "primary" else fallback_warning if field_type == "fallback" else null
	if not warning_label:
		return
	if cinematic_id.is_empty():
		warning_label.visible = false
		return
	var cinematics_dir: String = _get_active_mod_cinematics_path()
	if QuickDialogGenerator.cinematic_exists(cinematics_dir, cinematic_id):
		warning_label.visible = false
	else:
		warning_label.text = "Cinematic '%s' not found in any loaded mod" % cinematic_id
		warning_label.visible = true


func _update_cinematic_warnings() -> void:
	_validate_cinematic_field(interaction_cinematic_edit.text.strip_edges() if interaction_cinematic_edit else "", "primary")
	_validate_cinematic_field(fallback_cinematic_edit.text.strip_edges() if fallback_cinematic_edit else "", "fallback")


# =============================================================================
# Quick Dialog Creation (using QuickDialogGenerator)
# =============================================================================

func _on_create_dialog_cinematic() -> void:
	var dialog_text: String = quick_dialog_text.text.strip_edges()
	if dialog_text.is_empty():
		_show_error("Please enter dialog text first.")
		return

	var npc_id: String = npc_id_edit.text.strip_edges()
	if npc_id.is_empty():
		_show_error("Please set an NPC ID first.")
		return

	var speaker_name: String = npc_name_edit.text.strip_edges()
	var cinematics_dir: String = _get_active_mod_cinematics_path()
	if cinematics_dir.is_empty():
		_show_error("Could not determine active mod path.")
		return

	var cinematic_id: String = quick_dialog_generator.create_dialog_cinematic(npc_id, speaker_name, dialog_text, cinematics_dir)
	if cinematic_id.is_empty():
		_show_error("Failed to create cinematic.")
		return

	interaction_cinematic_edit.text = cinematic_id
	if current_resource and current_resource is NPCData:
		(current_resource as NPCData).interaction_cinematic_id = cinematic_id

	_show_quick_dialog_status("Created '%s' - Dialog is now attached!" % cinematic_id, Color(0.4, 0.9, 0.4))
	call_deferred("_update_cinematic_warnings")


func _show_quick_dialog_status(message: String, color: Color) -> void:
	if quick_dialog_status:
		quick_dialog_status.text = message
		quick_dialog_status.add_theme_color_override("font_color", color)
		quick_dialog_status.visible = true


func _update_quick_dialog_status() -> void:
	if not quick_dialog_status:
		return
	var primary_id: String = interaction_cinematic_edit.text.strip_edges() if interaction_cinematic_edit else ""
	if primary_id.is_empty():
		quick_dialog_status.visible = false
		return
	var npc_id: String = npc_id_edit.text.strip_edges() if npc_id_edit else ""
	var expected_quick_id: String = QuickDialogGenerator.get_quick_dialog_id(npc_id)
	if primary_id == expected_quick_id:
		_show_quick_dialog_status("Using Quick Dialog: '%s'" % primary_id, Color(0.4, 0.9, 0.4))
	else:
		_show_quick_dialog_status("Using cinematic: '%s' (edit below)" % primary_id, Color(0.6, 0.8, 1.0))


func _show_error(message: String) -> void:
	push_error("NPC Editor: " + message)
	_show_quick_dialog_status(message, Color(1.0, 0.4, 0.4))


# =============================================================================
# Place on Map (using MapPlacementHelper)
# =============================================================================

func _on_place_on_map_pressed() -> void:
	if not current_resource or not current_resource.resource_path or current_resource.resource_path.is_empty():
		_show_error("Please save the NPC first before placing on a map.")
		return
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
		map_list.add_item(map_info.get("display_name", "Unknown"))
		map_list.set_item_metadata(map_list.item_count - 1, map_info.get("path", ""))


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
		var scene_is_open: bool = MapPlacementHelper.is_scene_open(map_path)
		if scene_is_open:
			_show_quick_dialog_status("NPC added to scene - save to keep changes!", Color(0.4, 0.9, 0.4))
		else:
			_show_quick_dialog_status("NPC placed on %s at (%d, %d)" % [map_path.get_file().get_basename(), grid_x, grid_y], Color(0.4, 0.9, 0.4))
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


func _on_portrait_path_changed(new_text: String) -> void:
	if _updating_ui:
		return
	_load_portrait_preview(new_text)
	_update_preview()


func _load_portrait_preview(path: String) -> void:
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty():
		portrait_preview.texture = null
		portrait_preview.tooltip_text = "No portrait assigned"
		return

	if ResourceLoader.exists(clean_path):
		var texture: Texture2D = load(clean_path) as Texture2D
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


## Called when a spritesheet is selected in the MapSpritesheetPicker
func _on_spritesheet_selected(_path: String) -> void:
	if _updating_ui:
		return
	_update_preview()


## Called when SpriteFrames are generated from the selected spritesheet
func _on_sprite_frames_generated(_sprite_frames: SpriteFrames) -> void:
	if _updating_ui:
		return
	_update_preview()


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
