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

# UI field references - Basic Information
var npc_id_edit: LineEdit
var npc_name_edit: LineEdit
var character_picker: ResourcePicker

# Appearance Fallback section (visible when character_data is null)
var appearance_section: VBoxContainer
var portrait_path_edit: LineEdit
var portrait_browse_btn: Button
var map_sprite_path_edit: LineEdit
var map_sprite_browse_btn: Button

# Quick Dialog section (for simple NPCs)
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

# Track conditional entries for dynamic UI
var conditional_entries: Array[Dictionary] = []

# Flag to prevent signal feedback loops during UI updates
var _updating_ui: bool = false


func _ready() -> void:
	resource_type_name = "NPC"
	resource_type_id = "npc"
	super._ready()

	# Connect to EditorEventBus for refresh notifications
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	if event_bus:
		if not event_bus.mods_reloaded.is_connected(_on_mods_reloaded):
			event_bus.mods_reloaded.connect(_on_mods_reloaded)


func _exit_tree() -> void:
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	if event_bus:
		if event_bus.mods_reloaded.is_connected(_on_mods_reloaded):
			event_bus.mods_reloaded.disconnect(_on_mods_reloaded)


func _on_mods_reloaded() -> void:
	_refresh_list()


## Override: Create the NPC-specific detail form
func _create_detail_form() -> void:
	# Basic info section
	_add_basic_info_section()

	# Appearance fallback section (shown when no CharacterData)
	_add_appearance_fallback_section()

	# Quick Dialog section (for simple NPCs - type text, auto-create cinematic)
	_add_quick_dialog_section()

	# Interaction section (advanced cinematic configuration)
	_add_interaction_section()

	# Conditional cinematics section
	_add_conditional_cinematics_section()

	# Behavior section
	_add_behavior_section()

	# Add the button container at the end
	detail_panel.add_child(button_container)


## Override: Load NPC data from resource into UI
func _load_resource_data() -> void:
	var npc: NPCData = current_resource as NPCData
	if not npc:
		return

	_updating_ui = true

	# Basic info
	npc_id_edit.text = npc.npc_id
	npc_name_edit.text = npc.npc_name

	# Character data picker
	if npc.character_data:
		character_picker.select_resource(npc.character_data)
	else:
		character_picker.select_none()

	# Update appearance section visibility
	_update_appearance_section_visibility()

	# Appearance fallback (textures stored as paths for simplicity)
	portrait_path_edit.text = npc.portrait.resource_path if npc.portrait else ""
	map_sprite_path_edit.text = npc.map_sprite.resource_path if npc.map_sprite else ""

	# Interaction cinematics
	interaction_cinematic_edit.text = npc.interaction_cinematic_id
	fallback_cinematic_edit.text = npc.fallback_cinematic_id

	# Try to load Quick Dialog text from existing cinematic
	_load_quick_dialog_text(npc.npc_id, npc.interaction_cinematic_id)

	# Load conditional cinematics
	_load_conditional_cinematics(npc.conditional_cinematics)

	# Behavior
	face_player_check.button_pressed = npc.face_player_on_interact

	# Set facing override dropdown
	var facing_index: int = 0
	match npc.facing_override:
		"up":
			facing_index = 1
		"down":
			facing_index = 2
		"left":
			facing_index = 3
		"right":
			facing_index = 4
	facing_override_option.select(facing_index)

	_updating_ui = false

	# Validate cinematics after loading (deferred to ensure UI is ready)
	call_deferred("_update_cinematic_warnings")
	call_deferred("_update_quick_dialog_status")


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var npc: NPCData = current_resource as NPCData
	if not npc:
		return

	# Basic info
	npc.npc_id = npc_id_edit.text.strip_edges()
	npc.npc_name = npc_name_edit.text.strip_edges()

	# Character data
	npc.character_data = character_picker.get_selected_resource() as CharacterData

	# Appearance fallback - load textures if paths are valid
	var portrait_path: String = portrait_path_edit.text.strip_edges()
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		npc.portrait = load(portrait_path) as Texture2D
	else:
		npc.portrait = null

	var sprite_path: String = map_sprite_path_edit.text.strip_edges()
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		npc.map_sprite = load(sprite_path) as Texture2D
	else:
		npc.map_sprite = null

	# Interaction cinematics
	npc.interaction_cinematic_id = interaction_cinematic_edit.text.strip_edges()
	npc.fallback_cinematic_id = fallback_cinematic_edit.text.strip_edges()

	# Build conditional cinematics array from UI
	npc.conditional_cinematics = _collect_conditional_cinematics()

	# Behavior
	npc.face_player_on_interact = face_player_check.button_pressed

	# Get facing override from dropdown
	var facing_idx: int = facing_override_option.selected
	match facing_idx:
		0:
			npc.facing_override = ""
		1:
			npc.facing_override = "up"
		2:
			npc.facing_override = "down"
		3:
			npc.facing_override = "left"
		4:
			npc.facing_override = "right"


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	# npc_id is required
	var npc_id: String = npc_id_edit.text.strip_edges()
	if npc_id.is_empty():
		errors.append("NPC ID is required")

	# Check that at least one cinematic is defined
	var primary_id: String = interaction_cinematic_edit.text.strip_edges()
	var fallback_id: String = fallback_cinematic_edit.text.strip_edges()
	var has_primary: bool = not primary_id.is_empty()
	var has_fallback: bool = not fallback_id.is_empty()
	var has_conditional: bool = _has_valid_conditional()

	if not has_primary and not has_fallback and not has_conditional:
		errors.append("At least one cinematic must be defined (primary, fallback, or conditional)")

	# Warn about missing cinematics (not errors, but important to know)
	if has_primary and not _cinematic_exists(primary_id):
		warnings.append("Primary cinematic '%s' not found in loaded mods" % primary_id)

	if has_fallback and not _cinematic_exists(fallback_id):
		warnings.append("Fallback cinematic '%s' not found in loaded mods" % fallback_id)

	# Validate each conditional entry
	for i in range(conditional_entries.size()):
		var entry: Dictionary = conditional_entries[i]
		var flag_edit: LineEdit = entry.get("flag_edit") as LineEdit
		var cinematic_edit: LineEdit = entry.get("cinematic_edit") as LineEdit

		if flag_edit and cinematic_edit:
			var flag_text: String = flag_edit.text.strip_edges()
			var cine_text: String = cinematic_edit.text.strip_edges()

			# If either field has content, both must have content
			if (not flag_text.is_empty() and cine_text.is_empty()) or \
			   (flag_text.is_empty() and not cine_text.is_empty()):
				errors.append("Conditional entry %d: Both flag and cinematic ID are required" % (i + 1))
			elif not cine_text.is_empty() and not _cinematic_exists(cine_text):
				warnings.append("Conditional cinematic '%s' not found in loaded mods" % cine_text)

	return {valid = errors.is_empty(), errors = errors, warnings = warnings}


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

	# Try to set default placeholder textures from active mod
	var mod_path: String = _get_active_mod_base_path()
	if not mod_path.is_empty():
		var default_portrait: String = mod_path + "art/placeholder/portraits/npc.png"
		var default_sprite: String = mod_path + "art/placeholder/sprites/npc.png"

		if ResourceLoader.exists(default_portrait):
			new_npc.portrait = load(default_portrait) as Texture2D
		if ResourceLoader.exists(default_sprite):
			new_npc.map_sprite = load(default_sprite) as Texture2D

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
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Basic Information"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# NPC ID
	var id_container: HBoxContainer = HBoxContainer.new()
	var id_label: Label = Label.new()
	id_label.text = "NPC ID:"
	id_label.custom_minimum_size.x = 140
	id_container.add_child(id_label)

	npc_id_edit = LineEdit.new()
	npc_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	npc_id_edit.placeholder_text = "unique_npc_id"
	npc_id_edit.text_changed.connect(_on_field_changed)
	id_container.add_child(npc_id_edit)
	section.add_child(id_container)

	# NPC Name
	var name_container: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Display Name:"
	name_label.custom_minimum_size.x = 140
	name_container.add_child(name_label)

	npc_name_edit = LineEdit.new()
	npc_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	npc_name_edit.placeholder_text = "NPC Display Name"
	npc_name_edit.text_changed.connect(_on_field_changed)
	name_container.add_child(npc_name_edit)
	section.add_child(name_container)

	# Character Data - use ResourcePicker
	character_picker = ResourcePicker.new()
	character_picker.resource_type = "character"
	character_picker.label_text = "Character Data:"
	character_picker.label_min_width = 140
	character_picker.allow_none = true
	character_picker.none_text = "(Use fallback appearance)"
	character_picker.resource_selected.connect(_on_character_selected)
	section.add_child(character_picker)

	var char_help: Label = Label.new()
	char_help.text = "If set, portrait and sprite come from the character. Otherwise use fallback below."
	char_help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	char_help.add_theme_font_size_override("font_size", 12)
	section.add_child(char_help)

	detail_panel.add_child(section)


func _add_appearance_fallback_section() -> void:
	appearance_section = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Appearance (Fallback)"
	section_label.add_theme_font_size_override("font_size", 16)
	appearance_section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Used when no Character Data is assigned"
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_label.add_theme_font_size_override("font_size", 12)
	appearance_section.add_child(help_label)

	# Portrait path
	var portrait_container: HBoxContainer = HBoxContainer.new()
	var portrait_label: Label = Label.new()
	portrait_label.text = "Portrait:"
	portrait_label.custom_minimum_size.x = 140
	portrait_container.add_child(portrait_label)

	portrait_path_edit = LineEdit.new()
	portrait_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_path_edit.placeholder_text = "res://mods/<mod>/art/placeholder/portraits/npc.png"
	portrait_path_edit.text_changed.connect(_on_field_changed)
	portrait_container.add_child(portrait_path_edit)

	portrait_browse_btn = Button.new()
	portrait_browse_btn.text = "..."
	portrait_browse_btn.tooltip_text = "Browse for portrait texture"
	portrait_browse_btn.pressed.connect(_on_browse_portrait)
	portrait_container.add_child(portrait_browse_btn)

	appearance_section.add_child(portrait_container)

	# Map sprite path
	var sprite_container: HBoxContainer = HBoxContainer.new()
	var sprite_label: Label = Label.new()
	sprite_label.text = "Map Sprite:"
	sprite_label.custom_minimum_size.x = 140
	sprite_container.add_child(sprite_label)

	map_sprite_path_edit = LineEdit.new()
	map_sprite_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_sprite_path_edit.placeholder_text = "res://mods/<mod>/art/placeholder/sprites/npc.png"
	map_sprite_path_edit.text_changed.connect(_on_field_changed)
	sprite_container.add_child(map_sprite_path_edit)

	map_sprite_browse_btn = Button.new()
	map_sprite_browse_btn.text = "..."
	map_sprite_browse_btn.tooltip_text = "Browse for map sprite texture"
	map_sprite_browse_btn.pressed.connect(_on_browse_map_sprite)
	sprite_container.add_child(map_sprite_browse_btn)

	appearance_section.add_child(sprite_container)

	detail_panel.add_child(appearance_section)


func _add_quick_dialog_section() -> void:
	quick_dialog_section = VBoxContainer.new()

	var header_container: HBoxContainer = HBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "⚡ Quick Dialog"
	section_label.add_theme_font_size_override("font_size", 16)
	section_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(section_label)

	var collapse_hint: Label = Label.new()
	collapse_hint.text = "(for simple NPCs)"
	collapse_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	collapse_hint.add_theme_font_size_override("font_size", 12)
	header_container.add_child(collapse_hint)

	quick_dialog_section.add_child(header_container)

	# Status label - shows current state (created, in use, etc.)
	quick_dialog_status = Label.new()
	quick_dialog_status.add_theme_font_size_override("font_size", 12)
	quick_dialog_status.visible = false
	quick_dialog_section.add_child(quick_dialog_status)

	var help_label: Label = Label.new()
	help_label.text = "Type what this NPC says, then click the button to auto-create a cinematic."
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_label.add_theme_font_size_override("font_size", 12)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quick_dialog_section.add_child(help_label)

	# Multi-line text input for dialog
	quick_dialog_text = TextEdit.new()
	quick_dialog_text.placeholder_text = "Welcome to our village!\nFeel free to look around."
	quick_dialog_text.custom_minimum_size.y = 80
	quick_dialog_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_dialog_text.scroll_fit_content_height = true
	quick_dialog_section.add_child(quick_dialog_text)

	# Button to create cinematic
	create_dialog_btn = Button.new()
	create_dialog_btn.text = "Create Dialog Cinematic"
	create_dialog_btn.tooltip_text = "Generate a cinematic from this dialog and link it to this NPC"
	create_dialog_btn.pressed.connect(_on_create_dialog_cinematic)
	quick_dialog_section.add_child(create_dialog_btn)

	# Separator before advanced section
	var separator: HSeparator = HSeparator.new()
	separator.add_theme_constant_override("separation", 16)
	quick_dialog_section.add_child(separator)

	var advanced_label: Label = Label.new()
	advanced_label.text = "─── OR configure Advanced Cinematics below ───"
	advanced_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	advanced_label.add_theme_font_size_override("font_size", 11)
	advanced_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quick_dialog_section.add_child(advanced_label)

	var advanced_note: Label = Label.new()
	advanced_note.text = "(Advanced settings override Quick Dialog if both are set)"
	advanced_note.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	advanced_note.add_theme_font_size_override("font_size", 10)
	advanced_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quick_dialog_section.add_child(advanced_note)

	detail_panel.add_child(quick_dialog_section)


func _add_interaction_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Interaction"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Primary interaction cinematic
	var primary_container: HBoxContainer = HBoxContainer.new()
	var primary_label: Label = Label.new()
	primary_label.text = "Primary Cinematic:"
	primary_label.custom_minimum_size.x = 140
	primary_container.add_child(primary_label)

	interaction_cinematic_edit = LineEdit.new()
	interaction_cinematic_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interaction_cinematic_edit.placeholder_text = "cinematic_id"
	interaction_cinematic_edit.text_changed.connect(_on_cinematic_field_changed.bind("primary"))
	primary_container.add_child(interaction_cinematic_edit)
	section.add_child(primary_container)

	# Warning label for primary cinematic
	interaction_warning = Label.new()
	interaction_warning.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	interaction_warning.add_theme_font_size_override("font_size", 11)
	interaction_warning.visible = false
	section.add_child(interaction_warning)

	var primary_help: Label = Label.new()
	primary_help.text = "Default cinematic when player interacts (if no conditionals match)"
	primary_help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	primary_help.add_theme_font_size_override("font_size", 12)
	section.add_child(primary_help)

	# Fallback cinematic
	var fallback_container: HBoxContainer = HBoxContainer.new()
	var fallback_label: Label = Label.new()
	fallback_label.text = "Fallback Cinematic:"
	fallback_label.custom_minimum_size.x = 140
	fallback_container.add_child(fallback_label)

	fallback_cinematic_edit = LineEdit.new()
	fallback_cinematic_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fallback_cinematic_edit.placeholder_text = "fallback_cinematic_id"
	fallback_cinematic_edit.text_changed.connect(_on_cinematic_field_changed.bind("fallback"))
	fallback_container.add_child(fallback_cinematic_edit)
	section.add_child(fallback_container)

	# Warning label for fallback cinematic
	fallback_warning = Label.new()
	fallback_warning.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	fallback_warning.add_theme_font_size_override("font_size", 11)
	fallback_warning.visible = false
	section.add_child(fallback_warning)

	var fallback_help: Label = Label.new()
	fallback_help.text = "Last resort if no conditions match and no primary cinematic"
	fallback_help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	fallback_help.add_theme_font_size_override("font_size", 12)
	section.add_child(fallback_help)

	detail_panel.add_child(section)


func _add_conditional_cinematics_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var header_container: HBoxContainer = HBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Conditional Cinematics"
	section_label.add_theme_font_size_override("font_size", 16)
	section_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(section_label)

	add_conditional_btn = Button.new()
	add_conditional_btn.text = "+ Add Condition"
	add_conditional_btn.pressed.connect(_on_add_conditional)
	header_container.add_child(add_conditional_btn)

	section.add_child(header_container)

	var help_label: Label = Label.new()
	help_label.text = "Conditions checked in order. First matching condition's cinematic plays."
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_label.add_theme_font_size_override("font_size", 12)
	section.add_child(help_label)

	# Container for conditional entries (will be populated dynamically)
	conditionals_container = VBoxContainer.new()
	conditionals_container.add_theme_constant_override("separation", 4)
	section.add_child(conditionals_container)

	detail_panel.add_child(section)


func _add_behavior_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Behavior"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Face player on interact
	var face_container: HBoxContainer = HBoxContainer.new()
	var face_label: Label = Label.new()
	face_label.text = "Face Player:"
	face_label.custom_minimum_size.x = 140
	face_container.add_child(face_label)

	face_player_check = CheckBox.new()
	face_player_check.text = "Turn to face player when interaction starts"
	face_player_check.button_pressed = true
	face_player_check.toggled.connect(_on_check_changed)
	face_container.add_child(face_player_check)
	section.add_child(face_container)

	# Facing override
	var facing_container: HBoxContainer = HBoxContainer.new()
	var facing_label: Label = Label.new()
	facing_label.text = "Facing Override:"
	facing_label.custom_minimum_size.x = 140
	facing_container.add_child(facing_label)

	facing_override_option = OptionButton.new()
	facing_override_option.add_item("(Auto)", 0)
	facing_override_option.add_item("Up", 1)
	facing_override_option.add_item("Down", 2)
	facing_override_option.add_item("Left", 3)
	facing_override_option.add_item("Right", 4)
	facing_override_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facing_override_option.item_selected.connect(_on_option_changed)
	facing_container.add_child(facing_override_option)
	section.add_child(facing_container)

	var facing_help: Label = Label.new()
	facing_help.text = "Force NPC to always face a specific direction (overrides face player)"
	facing_help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	facing_help.add_theme_font_size_override("font_size", 12)
	section.add_child(facing_help)

	detail_panel.add_child(section)


# =============================================================================
# Conditional Cinematics UI Management
# =============================================================================

func _load_conditional_cinematics(conditionals: Array[Dictionary]) -> void:
	# Clear existing UI
	_clear_conditional_entries()

	# Create UI for each conditional
	for cond: Dictionary in conditionals:
		_add_conditional_entry(
			cond.get("flag", ""),
			cond.get("negate", false),
			cond.get("cinematic_id", "")
		)


func _add_conditional_entry(flag_name: String = "", negate: bool = false, cinematic_id: String = "") -> void:
	var entry_container: HBoxContainer = HBoxContainer.new()
	entry_container.add_theme_constant_override("separation", 4)

	# Flag name
	var flag_edit: LineEdit = LineEdit.new()
	flag_edit.placeholder_text = "flag_name"
	flag_edit.text = flag_name
	flag_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flag_edit.custom_minimum_size.x = 120
	flag_edit.text_changed.connect(_on_field_changed)
	entry_container.add_child(flag_edit)

	# Negate checkbox
	var negate_check: CheckBox = CheckBox.new()
	negate_check.text = "NOT"
	negate_check.tooltip_text = "Trigger when flag is NOT set"
	negate_check.button_pressed = negate
	negate_check.toggled.connect(_on_check_changed)
	entry_container.add_child(negate_check)

	# Arrow label
	var arrow: Label = Label.new()
	arrow.text = "->"
	entry_container.add_child(arrow)

	# Cinematic ID
	var cinematic_edit: LineEdit = LineEdit.new()
	cinematic_edit.placeholder_text = "cinematic_id"
	cinematic_edit.text = cinematic_id
	cinematic_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cinematic_edit.custom_minimum_size.x = 120
	cinematic_edit.text_changed.connect(_on_field_changed)
	entry_container.add_child(cinematic_edit)

	# Remove button
	var remove_btn: Button = Button.new()
	remove_btn.text = "X"
	remove_btn.tooltip_text = "Remove this condition"
	remove_btn.custom_minimum_size.x = 30
	remove_btn.pressed.connect(_on_remove_conditional.bind(entry_container))
	entry_container.add_child(remove_btn)

	conditionals_container.add_child(entry_container)

	# Track entry for later collection
	conditional_entries.append({
		"container": entry_container,
		"flag_edit": flag_edit,
		"negate_check": negate_check,
		"cinematic_edit": cinematic_edit
	})


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

		# Skip empty entries
		if flag_text.is_empty() and cine_text.is_empty():
			continue

		var cond_dict: Dictionary = {
			"flag": flag_text,
			"cinematic_id": cine_text
		}

		# Only include negate if true (to keep data clean)
		if negate_check and negate_check.button_pressed:
			cond_dict["negate"] = true

		result.append(cond_dict)

	return result


func _has_valid_conditional() -> bool:
	for entry: Dictionary in conditional_entries:
		var flag_edit: LineEdit = entry.get("flag_edit") as LineEdit
		var cinematic_edit: LineEdit = entry.get("cinematic_edit") as LineEdit

		if flag_edit and cinematic_edit:
			if not flag_edit.text.strip_edges().is_empty() and \
			   not cinematic_edit.text.strip_edges().is_empty():
				return true

	return false


# =============================================================================
# UI Event Handlers
# =============================================================================

func _on_add_conditional() -> void:
	_add_conditional_entry()
	_mark_dirty()


func _on_remove_conditional(entry_container: HBoxContainer) -> void:
	# Find and remove from tracking array
	for i in range(conditional_entries.size()):
		if conditional_entries[i].get("container") == entry_container:
			conditional_entries.remove_at(i)
			break

	entry_container.queue_free()
	_mark_dirty()


func _on_character_selected(_metadata: Dictionary) -> void:
	if _updating_ui:
		return
	_update_appearance_section_visibility()
	_mark_dirty()


func _update_appearance_section_visibility() -> void:
	# Show fallback appearance section only when no character is selected
	var has_character: bool = character_picker.has_selection()
	appearance_section.visible = not has_character


func _on_field_changed(_text: String) -> void:
	if _updating_ui:
		return
	_mark_dirty()


func _on_check_changed(_pressed: bool) -> void:
	if _updating_ui:
		return
	_mark_dirty()


func _on_option_changed(_index: int) -> void:
	if _updating_ui:
		return
	_mark_dirty()


func _mark_dirty() -> void:
	# The base class doesn't have an is_dirty property by default,
	# but we track changes for potential future undo/redo support
	pass


func _on_browse_portrait() -> void:
	# For now, just show a hint - proper file dialog requires EditorFileDialog
	# which has complex setup in editor plugins
	portrait_path_edit.placeholder_text = "Enter res:// path to portrait texture"


func _on_browse_map_sprite() -> void:
	map_sprite_path_edit.placeholder_text = "Enter res:// path to sprite texture"


## Handle cinematic field changes with validation
func _on_cinematic_field_changed(text: String, field_type: String) -> void:
	if _updating_ui:
		return

	# Validate the cinematic exists
	var cinematic_id: String = text.strip_edges()
	_validate_cinematic_field(cinematic_id, field_type)
	_mark_dirty()


## Validate a single cinematic field and update its warning label
func _validate_cinematic_field(cinematic_id: String, field_type: String) -> void:
	var warning_label: Label
	if field_type == "primary":
		warning_label = interaction_warning
	elif field_type == "fallback":
		warning_label = fallback_warning
	else:
		return

	if not warning_label:
		return

	# Empty field is valid (not required)
	if cinematic_id.is_empty():
		warning_label.visible = false
		return

	# Check if cinematic exists in registry
	if _cinematic_exists(cinematic_id):
		warning_label.visible = false
	else:
		warning_label.text = "⚠ Cinematic '%s' not found in any loaded mod" % cinematic_id
		warning_label.visible = true


## Check if a cinematic exists (in registry OR as file on disk)
func _cinematic_exists(cinematic_id: String) -> bool:
	# First check: file exists on disk in active mod
	var mod_path: String = _get_active_mod_cinematics_path()
	if not mod_path.is_empty():
		var file_path: String = mod_path + cinematic_id + ".json"
		if FileAccess.file_exists(file_path):
			return true

	# Second check: try ModLoader registry
	var mod_loader_node: Node = null
	if Engine.get_main_loop():
		mod_loader_node = Engine.get_main_loop().root.get_node_or_null("/root/ModLoader")

	if mod_loader_node:
		var registry: Variant = mod_loader_node.get("registry")
		if registry and registry.has_method("has_resource"):
			if registry.has_resource("cinematic", cinematic_id):
				return true

	# If we can't check registry and file doesn't exist, it's missing
	return false


## Update all cinematic warnings (called after loading or refreshing)
func _update_cinematic_warnings() -> void:
	var primary_id: String = interaction_cinematic_edit.text.strip_edges() if interaction_cinematic_edit else ""
	var fallback_id: String = fallback_cinematic_edit.text.strip_edges() if fallback_cinematic_edit else ""

	_validate_cinematic_field(primary_id, "primary")
	_validate_cinematic_field(fallback_id, "fallback")


# =============================================================================
# Quick Dialog Creation
# =============================================================================

## Handle the "Create Dialog Cinematic" button press
func _on_create_dialog_cinematic() -> void:
	# Validate dialog text
	var dialog_text: String = quick_dialog_text.text.strip_edges()
	if dialog_text.is_empty():
		_show_error("Please enter dialog text first.")
		return

	# Get NPC ID for cinematic naming
	var npc_id: String = npc_id_edit.text.strip_edges()
	if npc_id.is_empty():
		_show_error("Please set an NPC ID first.")
		return

	# Get NPC display name for speaker
	var speaker_name: String = npc_name_edit.text.strip_edges()
	if speaker_name.is_empty():
		speaker_name = npc_id.capitalize().replace("_", " ")

	# Generate cinematic ID
	var cinematic_id: String = npc_id + "_dialog"

	# Get active mod path
	var mod_path: String = _get_active_mod_cinematics_path()
	if mod_path.is_empty():
		_show_error("Could not determine active mod path.")
		return

	# Create the cinematic JSON
	var cinematic_data: Dictionary = _build_dialog_cinematic(cinematic_id, speaker_name, dialog_text)

	# Save the cinematic file
	var file_path: String = mod_path + cinematic_id + ".json"
	var success: bool = _save_cinematic_json(file_path, cinematic_data)

	if not success:
		_show_error("Failed to save cinematic file.")
		return

	# Set the primary cinematic field in UI
	interaction_cinematic_edit.text = cinematic_id

	# ALSO update the resource directly so it survives a refresh
	if current_resource and current_resource is NPCData:
		var npc: NPCData = current_resource as NPCData
		npc.interaction_cinematic_id = cinematic_id

	# Show success feedback
	_show_quick_dialog_status("✓ Created '%s' - Dialog is now attached!" % cinematic_id, Color(0.4, 0.9, 0.4))

	# Keep the text visible so user can see what was saved
	# (Don't clear it - helps user remember what the NPC says)

	# DON'T trigger mod reload - it causes list deselection issues
	# The cinematic file exists on disk, validation will check file existence
	# User can click "Refresh Mods" manually if needed for other features

	# Update warnings (should clear since cinematic file now exists)
	call_deferred("_update_cinematic_warnings")

	# Show success feedback
	print("NPC Editor: Created cinematic '%s' at %s" % [cinematic_id, file_path])


## Load Quick Dialog text from an existing cinematic file
func _load_quick_dialog_text(npc_id: String, cinematic_id: String) -> void:
	if not quick_dialog_text:
		return

	# Clear by default
	quick_dialog_text.text = ""

	# Only load if it's a Quick Dialog cinematic (matches expected pattern)
	if cinematic_id.is_empty():
		return

	var expected_quick_id: String = npc_id + "_dialog"
	if cinematic_id != expected_quick_id:
		# Not a Quick Dialog cinematic, don't populate
		return

	# Try to load the cinematic JSON file
	var mod_path: String = _get_active_mod_cinematics_path()
	if mod_path.is_empty():
		return

	var file_path: String = mod_path + cinematic_id + ".json"
	if not FileAccess.file_exists(file_path):
		return

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	if parse_result != OK:
		return

	var data: Dictionary = json.data as Dictionary
	if not data:
		return

	# Extract dialog text from commands
	var dialog_lines: PackedStringArray = []
	var commands: Array = data.get("commands", [])

	for command: Variant in commands:
		if command is Dictionary:
			var cmd: Dictionary = command as Dictionary
			if cmd.get("type") == "dialog_line":
				var params: Dictionary = cmd.get("params", {})
				var text: String = params.get("text", "")
				if not text.is_empty():
					dialog_lines.append(text)

	# Join lines and populate the text box
	if not dialog_lines.is_empty():
		quick_dialog_text.text = "\n".join(dialog_lines)


## Build a cinematic dictionary from dialog text
func _build_dialog_cinematic(cinematic_id: String, speaker_name: String, dialog_text: String) -> Dictionary:
	var commands: Array = []

	# Split dialog into lines for multi-line support
	var lines: PackedStringArray = dialog_text.split("\n")

	for line: String in lines:
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty():
			continue

		commands.append({
			"type": "dialog_line",
			"params": {
				"speaker_name": speaker_name,
				"text": trimmed,
				"emotion": "neutral"
			}
		})

	return {
		"cinematic_id": cinematic_id,
		"cinematic_name": "%s Dialog" % speaker_name,
		"description": "Auto-generated dialog for %s" % speaker_name,
		"can_skip": true,
		"disable_player_input": true,
		"commands": commands
	}


## Get the base path for the active mod
func _get_active_mod_base_path() -> String:
	# Try to get active mod from main panel
	var main_panel: Node = get_parent()
	while main_panel and not main_panel.has_method("get_active_mod_path"):
		main_panel = main_panel.get_parent()

	if main_panel and main_panel.has_method("get_active_mod_path"):
		var mod_path: String = main_panel.get_active_mod_path()
		if not mod_path.is_empty():
			return mod_path

	# Fallback: use _sandbox mod
	return "res://mods/_sandbox/"


## Get the cinematics folder path for the active mod
func _get_active_mod_cinematics_path() -> String:
	var base_path: String = _get_active_mod_base_path()
	return base_path + "data/cinematics/"


## Save cinematic data as JSON file
func _save_cinematic_json(file_path: String, data: Dictionary) -> bool:
	# Ensure directory exists
	var dir_path: String = file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err: Error = DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			push_error("Failed to create directory: " + dir_path)
			return false

	# Convert to JSON with pretty formatting
	var json_string: String = JSON.stringify(data, "  ")

	# Write file
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open file for writing: " + file_path)
		return false

	file.store_string(json_string)
	file.close()

	return true


## Trigger mod reload to pick up new resources
func _trigger_mod_reload() -> void:
	# Find main panel and trigger refresh
	var main_panel: Node = get_parent()
	while main_panel and not main_panel.has_method("_on_refresh_mods"):
		main_panel = main_panel.get_parent()

	if main_panel and main_panel.has_method("_on_refresh_mods"):
		main_panel._on_refresh_mods()


## Show an error message to the user
func _show_error(message: String) -> void:
	push_error("NPC Editor: " + message)
	_show_quick_dialog_status("✗ " + message, Color(1.0, 0.4, 0.4))


## Show status message in the Quick Dialog section
func _show_quick_dialog_status(message: String, color: Color) -> void:
	if quick_dialog_status:
		quick_dialog_status.text = message
		quick_dialog_status.add_theme_color_override("font_color", color)
		quick_dialog_status.visible = true


## Update Quick Dialog status based on current NPC state
func _update_quick_dialog_status() -> void:
	if not quick_dialog_status:
		return

	var primary_id: String = interaction_cinematic_edit.text.strip_edges() if interaction_cinematic_edit else ""

	if primary_id.is_empty():
		quick_dialog_status.visible = false
		return

	# Check if it's a quick dialog cinematic (ends with _dialog)
	var npc_id: String = npc_id_edit.text.strip_edges() if npc_id_edit else ""
	var expected_quick_id: String = npc_id + "_dialog"

	if primary_id == expected_quick_id:
		_show_quick_dialog_status("✓ Using Quick Dialog: '%s'" % primary_id, Color(0.4, 0.9, 0.4))
	else:
		_show_quick_dialog_status("ℹ Using cinematic: '%s' (edit below)" % primary_id, Color(0.6, 0.8, 1.0))
