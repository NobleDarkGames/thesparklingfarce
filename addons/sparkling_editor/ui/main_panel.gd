@tool
extends Control

## Main editor panel for The Sparkling Farce content editor
## Displays a tabbed interface for editing different types of content

const CharacterEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/character_editor.tscn")
const ClassEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/class_editor.tscn")
const ItemEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/item_editor.tscn")
const AbilityEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/ability_editor.tscn")
# DialogueEditorScene removed - dialog editing is now integrated into Cinematic Editor
# const DialogueEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/dialogue_editor.tscn")
# PartyEditorScene split into PartyTemplateEditor and SaveSlotEditor
const PartyTemplateEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/party_template_editor.tscn")
const SaveSlotEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/save_slot_editor.tscn")
const BattleEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/battle_editor.tscn")
const ModJsonEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/mod_json_editor.tscn")
const MapMetadataEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/map_metadata_editor.tscn")
const CinematicEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/cinematic_editor.tscn")
const CampaignEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/campaign_editor.tscn")
const TerrainEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/terrain_editor.tscn")
const NpcEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/npc_editor.tscn")

# Editor settings persistence
const EDITOR_SETTINGS_PATH: String = "user://sparkling_editor_settings.json"

var character_editor: Control
var class_editor: Control
var item_editor: Control
var ability_editor: Control
# dialogue_editor removed - dialog editing is now integrated into Cinematic Editor
# party_editor split into party_template_editor and save_slot_editor
var party_template_editor: Control
var save_slot_editor: Control
var battle_editor: Control
var mod_json_editor: Control
var map_metadata_editor: Control
var cinematic_editor: Control
var campaign_editor: Control
var terrain_editor: Control
var npc_editor: Control

# Dynamic editor tabs from mods
# Format: {"mod_id:tab_id": {"control": Control, "refresh_method": String}}
var dynamic_editors: Dictionary = {}

var tab_container: TabContainer
var mod_selector: OptionButton
var mod_info_label: Label

# Mod Creation Wizard
var create_mod_dialog: ConfirmationDialog
var wizard_mod_id_edit: LineEdit
var wizard_mod_name_edit: LineEdit
var wizard_author_edit: LineEdit
var wizard_description_edit: TextEdit
var wizard_type_dropdown: OptionButton
var wizard_error_label: Label


func _init() -> void:
	# Editor plugins don't reliably call _ready, so we use _init with deferred setup
	call_deferred("_setup_ui")


func _ready() -> void:
	pass


func _setup_ui() -> void:
	# Get the TabContainer from the scene
	tab_container = get_node("TabContainer")

	if not tab_container:
		push_error("TabContainer not found in scene!")
		return

	# Set minimum width to prevent collapse, but allow vertical scaling
	# Note: Minimum height removed to fix vertical overflow in bottom panel
	custom_minimum_size = Vector2(800, 0)

	# IMPORTANT: Change TabContainer anchors to not fill full height
	# This makes room for the mod selector panel above it
	tab_container.anchor_bottom = 1.0
	tab_container.offset_top = 40  # Leave space for mod selector (40px)
	tab_container.offset_bottom = 0

	# Add mod selector UI at the top
	_create_mod_selector_ui()

	# Make tabs more visible with custom theme overrides
	tab_container.add_theme_font_size_override("font_size", 16)
	tab_container.add_theme_constant_override("side_margin", 10)

	# Create editor tabs - Overview first so it shows by default
	_create_overview_tab()
	_create_mod_settings_tab()
	_create_class_editor_tab()
	_create_character_editor_tab()
	_create_item_editor_tab()
	_create_ability_editor_tab()
	# _create_dialogue_editor_tab() removed - dialog editing is now in Cinematic Editor
	_create_party_template_editor_tab()
	_create_save_slot_editor_tab()
	_create_battle_editor_tab()
	_create_map_metadata_tab()
	_create_cinematic_editor_tab()
	_create_campaign_editor_tab()
	_create_terrain_editor_tab()
	_create_npc_editor_tab()

	# Load dynamic editor tabs from mods
	_load_mod_editor_extensions()


func _create_overview_tab() -> void:
	var overview: VBoxContainer = VBoxContainer.new()
	overview.name = "Overview"

	var title: Label = Label.new()
	title.text = "The Sparkling Farce - Content Editor"
	title.add_theme_font_size_override("font_size", 24)
	overview.add_child(title)

	# Wrap description in ScrollContainer to prevent it from forcing large height
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var description: RichTextLabel = RichTextLabel.new()
	description.bbcode_enabled = true
	description.text = """[b]Welcome to the Sparkling Editor![/b]

This editor allows you to create content for your tactical RPG game without writing code.

[b]Quick Start:[/b]
• Use the tabs above to browse and edit different types of content
• Use the Tools menu to create new characters, classes, items, and abilities
• All content is saved in the data/ folder as .tres Resource files
• You can also edit Resources directly in the Godot Inspector

[b]Content Types:[/b]
• [b]Characters:[/b] Create playable units and enemies with stats and equipment
• [b]Classes:[/b] Define character classes with movement and abilities
• [b]Items:[/b] Create weapons, armor, and consumable items
• [b]Abilities:[/b] Define skills and spells for combat
• [b]Parties:[/b] Create and manage party compositions for battles
• [b]Battles:[/b] Configure tactical battle scenarios with enemies and objectives
• [b]Maps:[/b] Configure map metadata and connections
• [b]Cinematics:[/b] Create cutscenes and narrative sequences with dialog

[b]Next Steps:[/b]
1. Create some classes first (they're required for characters)
2. Create abilities that classes can learn
3. Create characters and assign them classes
4. Create items for characters to equip

For more information, check the documentation in the user_content folder."""
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.fit_content = true

	scroll.add_child(description)
	overview.add_child(scroll)

	tab_container.add_child(overview)


func _create_mod_settings_tab() -> void:
	mod_json_editor = ModJsonEditorScene.instantiate()
	mod_json_editor.name = "Mod Settings"
	tab_container.add_child(mod_json_editor)


func _create_character_editor_tab() -> void:
	character_editor = CharacterEditorScene.instantiate()
	tab_container.add_child(character_editor)


func _create_class_editor_tab() -> void:
	class_editor = ClassEditorScene.instantiate()
	tab_container.add_child(class_editor)


func _create_item_editor_tab() -> void:
	item_editor = ItemEditorScene.instantiate()
	tab_container.add_child(item_editor)


func _create_ability_editor_tab() -> void:
	ability_editor = AbilityEditorScene.instantiate()
	tab_container.add_child(ability_editor)


# _create_dialogue_editor_tab() removed - dialog editing is now in Cinematic Editor


func _create_party_template_editor_tab() -> void:
	party_template_editor = PartyTemplateEditorScene.instantiate()
	party_template_editor.name = "Party Templates"
	tab_container.add_child(party_template_editor)


func _create_save_slot_editor_tab() -> void:
	save_slot_editor = SaveSlotEditorScene.instantiate()
	save_slot_editor.name = "Save Slots"
	tab_container.add_child(save_slot_editor)


func _create_battle_editor_tab() -> void:
	battle_editor = BattleEditorScene.instantiate()
	tab_container.add_child(battle_editor)


func _create_map_metadata_tab() -> void:
	map_metadata_editor = MapMetadataEditorScene.instantiate()
	map_metadata_editor.name = "Maps"
	tab_container.add_child(map_metadata_editor)


func _create_cinematic_editor_tab() -> void:
	cinematic_editor = CinematicEditorScene.instantiate()
	cinematic_editor.name = "Cinematics"
	tab_container.add_child(cinematic_editor)


func _create_campaign_editor_tab() -> void:
	campaign_editor = CampaignEditorScene.instantiate()
	campaign_editor.name = "Campaigns"
	tab_container.add_child(campaign_editor)


func _create_terrain_editor_tab() -> void:
	terrain_editor = TerrainEditorScene.instantiate()
	terrain_editor.name = "Terrain"
	tab_container.add_child(terrain_editor)


func _create_npc_editor_tab() -> void:
	npc_editor = NpcEditorScene.instantiate()
	npc_editor.name = "NPCs"
	tab_container.add_child(npc_editor)


func _load_mod_editor_extensions() -> void:
	## Discover and load editor extensions from all mods
	## Mods can define editor_extensions in mod.json to add custom tabs

	if not ModLoader:
		return

	# Clear existing dynamic editors
	for key: String in dynamic_editors.keys():
		var editor_info: Dictionary = dynamic_editors[key]
		if editor_info.get("control"):
			editor_info["control"].queue_free()
	dynamic_editors.clear()

	var mods: Array[ModManifest] = ModLoader.get_all_mods()

	for mod: ModManifest in mods:
		if mod.editor_extensions.is_empty():
			continue

		for ext_id: String in mod.editor_extensions.keys():
			var ext_config: Dictionary = mod.editor_extensions[ext_id]
			_register_mod_editor(mod, ext_id, ext_config)


func _register_mod_editor(mod: ModManifest, ext_id: String, config: Dictionary) -> void:
	## Register a single mod editor tab
	## config format: {editor_scene: String, tab_name: String, refresh_method: String (optional)}

	var editor_scene_path: String = config.get("editor_scene", "")
	var tab_name: String = config.get("tab_name", ext_id)
	var refresh_method: String = config.get("refresh_method", "_refresh_list")

	if editor_scene_path.is_empty():
		push_warning("Mod '%s' editor_extension '%s' missing editor_scene" % [mod.mod_id, ext_id])
		return

	# Resolve full path (relative to mod directory)
	var full_scene_path: String = mod.mod_directory.path_join(editor_scene_path)

	# Check if scene exists
	if not ResourceLoader.exists(full_scene_path):
		push_warning("Mod '%s' editor_extension '%s' scene not found: %s" % [mod.mod_id, ext_id, full_scene_path])
		return

	# Load and instantiate the scene
	var scene: PackedScene = load(full_scene_path)
	if not scene:
		push_error("Failed to load mod editor scene: " + full_scene_path)
		return

	var editor_instance: Control = scene.instantiate()
	if not editor_instance:
		push_error("Failed to instantiate mod editor: " + full_scene_path)
		return

	# Set tab name with mod prefix for clarity
	editor_instance.name = "[%s] %s" % [mod.mod_id, tab_name]

	# Add to tab container
	tab_container.add_child(editor_instance)

	# Track for refresh calls
	var editor_key: String = "%s:%s" % [mod.mod_id, ext_id]
	dynamic_editors[editor_key] = {
		"control": editor_instance,
		"refresh_method": refresh_method,
		"mod_id": mod.mod_id,
		"tab_name": tab_name
	}

	# Mod editor tab registered successfully


func _create_mod_selector_ui() -> void:
	# Create container for mod selector (above TabContainer)
	var mod_panel: PanelContainer = PanelContainer.new()
	mod_panel.name = "ModSelectorPanel"

	# Position it at the top
	mod_panel.anchor_right = 1.0
	mod_panel.offset_bottom = 40  # 40px tall
	mod_panel.size_flags_horizontal = Control.SIZE_FILL

	# Insert before TabContainer
	var tab_index: int = tab_container.get_index()
	add_child(mod_panel)
	move_child(mod_panel, tab_index)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	mod_panel.add_child(hbox)

	# Label
	var label: Label = Label.new()
	label.text = "Active Mod:"
	label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(label)

	# Mod selector dropdown
	mod_selector = OptionButton.new()
	mod_selector.custom_minimum_size = Vector2(200, 0)
	mod_selector.item_selected.connect(_on_mod_selected)
	hbox.add_child(mod_selector)

	# Mod info label
	mod_info_label = Label.new()
	mod_info_label.add_theme_color_override("font_color", EditorThemeUtils.get_disabled_color())
	mod_info_label.add_theme_font_size_override("font_size", 16)
	mod_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(mod_info_label)

	# Refresh button
	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh Mods"
	refresh_button.pressed.connect(_on_refresh_mods)
	hbox.add_child(refresh_button)

	# Create New Mod button
	var create_mod_button: Button = Button.new()
	create_mod_button.text = "Create New Mod"
	create_mod_button.tooltip_text = "Create a new mod with folder structure and mod.json"
	create_mod_button.pressed.connect(_show_create_mod_wizard)
	hbox.add_child(create_mod_button)

	# Populate mod list
	_refresh_mod_list()


func _refresh_mod_list() -> void:
	if not mod_selector:
		return

	mod_selector.clear()

	if not ModLoader:
		push_warning("ModLoader not available")
		return

	var mods: Array[ModManifest] = ModLoader.get_all_mods()
	var active_index: int = 0

	# Try to restore persisted mod selection, fall back to ModLoader's active mod
	var persisted_mod_id: String = _load_last_selected_mod()
	var target_mod_id: String = ""

	if not persisted_mod_id.is_empty() and ModLoader.get_mod(persisted_mod_id):
		target_mod_id = persisted_mod_id
	else:
		var active_mod: ModManifest = ModLoader.get_active_mod()
		if active_mod:
			target_mod_id = active_mod.mod_id

	for i in range(mods.size()):
		var mod: ModManifest = mods[i]
		mod_selector.add_item(mod.mod_name, i)
		mod_selector.set_item_metadata(i, mod.mod_id)

		if mod.mod_id == target_mod_id:
			active_index = i

	# Select and sync the active mod
	if mods.size() > 0:
		mod_selector.select(active_index)
		_update_mod_info(active_index)

		# Ensure ModLoader is synced with our selection
		var selected_mod_id: String = mod_selector.get_item_metadata(active_index)
		if ModLoader.get_active_mod() == null or ModLoader.get_active_mod().mod_id != selected_mod_id:
			ModLoader.set_active_mod(selected_mod_id)


func _on_mod_selected(index: int) -> void:
	var mod_id: String = mod_selector.get_item_metadata(index)

	if ModLoader and ModLoader.set_active_mod(mod_id):
		# Persist the selection for next session
		_save_last_selected_mod(mod_id)

		# Notify all editors that the active mod changed
		var event_bus: Node = get_node_or_null("/root/EditorEventBus")
		if event_bus:
			event_bus.active_mod_changed.emit(mod_id)

		_update_mod_info(index)
		_refresh_all_editors()
	else:
		push_error("Failed to set active mod: " + mod_id)


func _update_mod_info(index: int) -> void:
	if not mod_info_label or not mod_selector:
		return

	var mod_id: String = mod_selector.get_item_metadata(index)
	var mod: ModManifest = ModLoader.get_mod(mod_id)

	if mod:
		mod_info_label.text = "v%s by %s | Priority: %d" % [mod.version, mod.author, mod.load_priority]
	else:
		mod_info_label.text = ""


func _on_refresh_mods() -> void:
	if ModLoader:
		ModLoader.reload_mods()

		# Notify all editors that mods were reloaded
		var event_bus: Node = get_node_or_null("/root/EditorEventBus")
		if event_bus:
			event_bus.mods_reloaded.emit()

		_refresh_mod_list()

		# Reload dynamic editor tabs (mods may have added/removed extensions)
		_load_mod_editor_extensions()

		_refresh_all_editors()


## Get the active mod's root path (for saving resources to the correct mod)
func get_active_mod_path() -> String:
	if ModLoader:
		var active_mod: ModManifest = ModLoader.get_active_mod()
		if active_mod:
			return "res://mods/" + active_mod.mod_id + "/"
	return ""


func _refresh_all_editors() -> void:
	# Refresh all editor lists to show content from active mod
	if character_editor and character_editor.has_method("_refresh_list"):
		character_editor._refresh_list()
	if class_editor and class_editor.has_method("_refresh_list"):
		class_editor._refresh_list()
	if item_editor and item_editor.has_method("_refresh_list"):
		item_editor._refresh_list()
	if ability_editor and ability_editor.has_method("_refresh_list"):
		ability_editor._refresh_list()
	# dialogue_editor removed - dialog editing is now in Cinematic Editor
	# party_editor split into party_template_editor and save_slot_editor
	if party_template_editor and party_template_editor.has_method("_refresh_list"):
		party_template_editor._refresh_list()
	# save_slot_editor doesn't need refresh - it operates on save files, not mod resources
	if battle_editor and battle_editor.has_method("_refresh_list"):
		battle_editor._refresh_list()
	if mod_json_editor and mod_json_editor.has_method("_refresh_mod_list"):
		mod_json_editor._refresh_mod_list()
	if map_metadata_editor and map_metadata_editor.has_method("_refresh_map_list"):
		map_metadata_editor._refresh_map_list()
	if cinematic_editor and cinematic_editor.has_method("_refresh_cinematic_list"):
		cinematic_editor._refresh_cinematic_list()
	if campaign_editor and campaign_editor.has_method("_refresh_campaign_list"):
		campaign_editor._refresh_campaign_list()
	if terrain_editor and terrain_editor.has_method("_refresh_list"):
		terrain_editor._refresh_list()
	if npc_editor and npc_editor.has_method("_refresh_list"):
		npc_editor._refresh_list()

	# Refresh dynamic mod editors
	for key: String in dynamic_editors.keys():
		var editor_info: Dictionary = dynamic_editors[key]
		var editor_control: Control = editor_info.get("control")
		var refresh_method: String = editor_info.get("refresh_method", "_refresh_list")
		# Security: Only allow calling methods that start with "refresh" or "_refresh"
		if not _is_safe_refresh_method(refresh_method):
			push_warning("Dynamic editor '%s' has unsafe refresh_method '%s' - skipping" % [key, refresh_method])
			continue
		if editor_control and editor_control.has_method(refresh_method):
			editor_control.call(refresh_method)


## Validate that a refresh method name is safe to call
## Only allows methods starting with "refresh" or "_refresh" to prevent calling
## destructive methods like queue_free, remove_child, etc.
func _is_safe_refresh_method(method_name: String) -> bool:
	return method_name.begins_with("refresh") or method_name.begins_with("_refresh")


# =============================================================================
# Settings Persistence
# =============================================================================

## Save the last selected mod ID for restoration on next editor load
func _save_last_selected_mod(mod_id: String) -> void:
	var settings: Dictionary = _load_editor_settings()
	settings["last_selected_mod"] = mod_id
	_save_editor_settings(settings)


## Load the last selected mod ID, returns empty string if not set
func _load_last_selected_mod() -> String:
	var settings: Dictionary = _load_editor_settings()
	return settings.get("last_selected_mod", "")


## Load editor settings from file
func _load_editor_settings() -> Dictionary:
	if not FileAccess.file_exists(EDITOR_SETTINGS_PATH):
		return {}

	var file: FileAccess = FileAccess.open(EDITOR_SETTINGS_PATH, FileAccess.READ)
	if not file:
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if parsed is Dictionary:
		return parsed

	return {}


## Save editor settings to file
func _save_editor_settings(settings: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(EDITOR_SETTINGS_PATH, FileAccess.WRITE)
	if not file:
		push_warning("Failed to save editor settings to: " + EDITOR_SETTINGS_PATH)
		return

	file.store_string(JSON.stringify(settings, "\t"))
	file.close()


# =============================================================================
# Mod Creation Wizard
# =============================================================================

## Show the Create New Mod wizard dialog
func _show_create_mod_wizard() -> void:
	if not create_mod_dialog:
		_create_mod_wizard_dialog()

	# Reset fields
	wizard_mod_id_edit.text = ""
	wizard_mod_name_edit.text = ""
	wizard_author_edit.text = ""
	wizard_description_edit.text = ""
	wizard_type_dropdown.select(0)
	wizard_error_label.text = ""
	wizard_error_label.visible = false

	create_mod_dialog.popup_centered()


## Create the wizard dialog UI
func _create_mod_wizard_dialog() -> void:
	create_mod_dialog = ConfirmationDialog.new()
	create_mod_dialog.title = "Create New Mod"
	create_mod_dialog.ok_button_text = "Create Mod"
	create_mod_dialog.min_size = Vector2(500, 400)
	create_mod_dialog.confirmed.connect(_on_create_mod_confirmed)
	add_child(create_mod_dialog)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	create_mod_dialog.add_child(vbox)

	# Mod ID
	var id_label: Label = Label.new()
	id_label.text = "Mod ID (folder name, no spaces):"
	vbox.add_child(id_label)

	wizard_mod_id_edit = LineEdit.new()
	wizard_mod_id_edit.placeholder_text = "my_awesome_mod"
	wizard_mod_id_edit.text_changed.connect(_on_wizard_mod_id_changed)
	vbox.add_child(wizard_mod_id_edit)

	# Mod Name
	var name_label: Label = Label.new()
	name_label.text = "Display Name:"
	vbox.add_child(name_label)

	wizard_mod_name_edit = LineEdit.new()
	wizard_mod_name_edit.placeholder_text = "My Awesome Mod"
	vbox.add_child(wizard_mod_name_edit)

	# Author
	var author_label: Label = Label.new()
	author_label.text = "Author:"
	vbox.add_child(author_label)

	wizard_author_edit = LineEdit.new()
	wizard_author_edit.placeholder_text = "Your Name"
	vbox.add_child(wizard_author_edit)

	# Description
	var desc_label: Label = Label.new()
	desc_label.text = "Description:"
	vbox.add_child(desc_label)

	wizard_description_edit = TextEdit.new()
	wizard_description_edit.placeholder_text = "A brief description of your mod..."
	wizard_description_edit.custom_minimum_size = Vector2(0, 60)
	vbox.add_child(wizard_description_edit)

	# Mod Type
	var type_label: Label = Label.new()
	type_label.text = "Mod Type:"
	vbox.add_child(type_label)

	wizard_type_dropdown = OptionButton.new()
	wizard_type_dropdown.add_item("Content Expansion (Priority 100-199)")
	wizard_type_dropdown.set_item_metadata(0, {"priority": 100, "type": "expansion"})
	wizard_type_dropdown.add_item("Override Pack (Priority 500-899)")
	wizard_type_dropdown.set_item_metadata(1, {"priority": 500, "type": "override"})
	wizard_type_dropdown.add_item("Total Conversion (Priority 9000+)")
	wizard_type_dropdown.set_item_metadata(2, {"priority": 9000, "type": "total_conversion"})
	vbox.add_child(wizard_type_dropdown)

	# Type help text
	var type_help: Label = Label.new()
	type_help.text = "Content Expansion: Adds new content alongside base game\n" + \
		"Override Pack: Replaces specific base game content\n" + \
		"Total Conversion: Completely replaces the base game"
	type_help.add_theme_color_override("font_color", EditorThemeUtils.get_disabled_color())
	type_help.add_theme_font_size_override("font_size", 12)
	vbox.add_child(type_help)

	# Error label
	wizard_error_label = Label.new()
	wizard_error_label.add_theme_color_override("font_color", EditorThemeUtils.get_error_color())
	wizard_error_label.visible = false
	vbox.add_child(wizard_error_label)


## Auto-generate mod name from ID
func _on_wizard_mod_id_changed(new_id: String) -> void:
	# Convert snake_case to Title Case for display name
	if wizard_mod_name_edit.text.is_empty() or _is_auto_generated_name(wizard_mod_name_edit.text):
		var words: PackedStringArray = new_id.split("_")
		var title_words: Array = []
		for word: String in words:
			if not word.is_empty():
				title_words.append(word.capitalize())
		wizard_mod_name_edit.text = " ".join(title_words)


## Check if the name looks auto-generated
func _is_auto_generated_name(name: String) -> bool:
	var id: String = wizard_mod_id_edit.text
	var words: PackedStringArray = id.split("_")
	var title_words: Array = []
	for word: String in words:
		if not word.is_empty():
			title_words.append(word.capitalize())
	return name == " ".join(title_words)


## Validate and create the mod
func _on_create_mod_confirmed() -> void:
	var mod_id: String = wizard_mod_id_edit.text.strip_edges()
	var mod_name: String = wizard_mod_name_edit.text.strip_edges()
	var author: String = wizard_author_edit.text.strip_edges()
	var description: String = wizard_description_edit.text.strip_edges()
	var type_data: Dictionary = wizard_type_dropdown.get_item_metadata(wizard_type_dropdown.selected)

	# Validation
	if mod_id.is_empty():
		_show_wizard_error("Mod ID is required")
		return

	# Validate mod ID format
	if not _is_valid_mod_id(mod_id):
		_show_wizard_error("Mod ID can only contain lowercase letters, numbers, and underscores")
		return

	# Check if mod already exists
	var mod_path: String = "res://mods/" + mod_id + "/"
	if DirAccess.dir_exists_absolute(mod_path):
		_show_wizard_error("A mod with this ID already exists")
		return

	if mod_name.is_empty():
		mod_name = mod_id.replace("_", " ").capitalize()

	# Create the mod
	var success: bool = _create_mod_structure(mod_id, mod_name, author, description, type_data)
	if success:
		# Reload mods to pick up the new one
		if ModLoader:
			ModLoader.reload_mods()
			_refresh_mod_list()

			# Select the new mod
			ModLoader.set_active_mod(mod_id)
			for i in range(mod_selector.item_count):
				if mod_selector.get_item_metadata(i) == mod_id:
					mod_selector.select(i)
					_on_mod_selected(i)
					break

			# Notify all editors
			var event_bus: Node = get_node_or_null("/root/EditorEventBus")
			if event_bus:
				event_bus.active_mod_changed.emit(mod_id)

			_refresh_all_editors()

		create_mod_dialog.hide()
	else:
		_show_wizard_error("Failed to create mod folder structure")


## Validate mod ID format
func _is_valid_mod_id(mod_id: String) -> bool:
	var regex: RegEx = RegEx.new()
	regex.compile("^[a-z][a-z0-9_]*$")
	return regex.search(mod_id) != null


## Show error in wizard dialog
func _show_wizard_error(message: String) -> void:
	wizard_error_label.text = message
	wizard_error_label.visible = true


## Create the mod folder structure and mod.json
func _create_mod_structure(mod_id: String, mod_name: String, author: String, description: String, type_data: Dictionary) -> bool:
	var mod_path: String = "res://mods/" + mod_id + "/"

	# Create main folder
	var err: Error = DirAccess.make_dir_recursive_absolute(mod_path)
	if err != OK:
		push_error("Failed to create mod directory: " + mod_path)
		return false

	# Create standard subdirectories
	var subdirs: Array = [
		"data/characters",
		"data/classes",
		"data/items",
		"data/abilities",
		"data/battles",
		"data/parties",
		"data/dialogues",
		"data/campaigns",
		"data/cinematics",
		"data/maps",
		"data/npcs",
		"data/terrain",
		"assets/icons",
		"assets/portraits",
		"assets/sprites",
		"assets/audio",
		"maps",
		"scenes",
		"tilesets",
		"triggers"
	]

	for subdir: String in subdirs:
		err = DirAccess.make_dir_recursive_absolute(mod_path + subdir)
		if err != OK:
			push_warning("Failed to create subdirectory: " + subdir)

	# Generate mod.json
	var mod_json: Dictionary = {
		"id": mod_id,
		"name": mod_name,
		"version": "1.0.0",
		"author": author if not author.is_empty() else "Unknown",
		"description": description if not description.is_empty() else "A new mod for The Sparkling Farce",
		"godot_version": "4.5",
		"load_priority": type_data.priority,
		"dependencies": []
	}

	# Add type-specific settings
	if type_data.type == "total_conversion":
		mod_json["hidden_campaigns"] = ["_base_game:*"]
		mod_json["party_config"] = {"replaces_lower_priority": true}
	elif type_data.type == "override":
		mod_json["party_config"] = {"replaces_lower_priority": false}

	# Write mod.json
	var json_path: String = mod_path + "mod.json"
	var file: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to create mod.json: " + json_path)
		return false

	file.store_string(JSON.stringify(mod_json, "\t"))
	file.close()

	return true
