@tool
extends Control

## Main editor panel for The Sparkling Farce content editor
## Displays a tabbed interface for editing different types of content

const CharacterEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/character_editor.tscn")
const ClassEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/class_editor.tscn")
const ItemEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/item_editor.tscn")
const AbilityEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/ability_editor.tscn")
const DialogueEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/dialogue_editor.tscn")
const PartyEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/party_editor.tscn")
const BattleEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/battle_editor.tscn")
const ModJsonEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/mod_json_editor.tscn")
const MapMetadataEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/map_metadata_editor.tscn")

var character_editor: Control
var class_editor: Control
var item_editor: Control
var ability_editor: Control
var dialogue_editor: Control
var party_editor: Control
var battle_editor: Control
var mod_json_editor: Control
var map_metadata_editor: Control

var tab_container: TabContainer
var mod_selector: OptionButton
var mod_info_label: Label


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
	tab_container.add_theme_font_size_override("font_size", 14)
	tab_container.add_theme_constant_override("side_margin", 10)

	# Create editor tabs - Overview first so it shows by default
	_create_overview_tab()
	_create_mod_settings_tab()
	_create_class_editor_tab()
	_create_character_editor_tab()
	_create_item_editor_tab()
	_create_ability_editor_tab()
	_create_dialogue_editor_tab()
	_create_party_editor_tab()
	_create_battle_editor_tab()
	_create_map_metadata_tab()


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
• [b]Dialogues:[/b] Create conversations and cutscenes
• [b]Parties:[/b] Create and manage party compositions for battles
• [b]Battles:[/b] Configure tactical battle scenarios with enemies and objectives

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


func _create_dialogue_editor_tab() -> void:
	dialogue_editor = DialogueEditorScene.instantiate()
	tab_container.add_child(dialogue_editor)


func _create_party_editor_tab() -> void:
	party_editor = PartyEditorScene.instantiate()
	tab_container.add_child(party_editor)


func _create_battle_editor_tab() -> void:
	battle_editor = BattleEditorScene.instantiate()
	tab_container.add_child(battle_editor)


func _create_map_metadata_tab() -> void:
	map_metadata_editor = MapMetadataEditorScene.instantiate()
	map_metadata_editor.name = "Maps"
	tab_container.add_child(map_metadata_editor)


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
	label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(label)

	# Mod selector dropdown
	mod_selector = OptionButton.new()
	mod_selector.custom_minimum_size = Vector2(200, 0)
	mod_selector.item_selected.connect(_on_mod_selected)
	hbox.add_child(mod_selector)

	# Mod info label
	mod_info_label = Label.new()
	mod_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	mod_info_label.add_theme_font_size_override("font_size", 12)
	mod_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(mod_info_label)

	# Refresh button
	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh Mods"
	refresh_button.pressed.connect(_on_refresh_mods)
	hbox.add_child(refresh_button)

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
	var active_mod: ModManifest = ModLoader.get_active_mod()
	var active_index: int = 0

	for i in range(mods.size()):
		var mod: ModManifest = mods[i]
		mod_selector.add_item(mod.mod_name, i)
		mod_selector.set_item_metadata(i, mod.mod_id)

		if active_mod and mod.mod_id == active_mod.mod_id:
			active_index = i

	# Select the active mod
	if mods.size() > 0:
		mod_selector.select(active_index)
		_update_mod_info(active_index)


func _on_mod_selected(index: int) -> void:
	var mod_id: String = mod_selector.get_item_metadata(index)

	if ModLoader and ModLoader.set_active_mod(mod_id):
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
		_refresh_all_editors()


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
	if dialogue_editor and dialogue_editor.has_method("_refresh_list"):
		dialogue_editor._refresh_list()
	if party_editor and party_editor.has_method("_refresh_list"):
		party_editor._refresh_list()
	if battle_editor and battle_editor.has_method("_refresh_list"):
		battle_editor._refresh_list()
	if mod_json_editor and mod_json_editor.has_method("_refresh_mod_list"):
		mod_json_editor._refresh_mod_list()
	if map_metadata_editor and map_metadata_editor.has_method("_refresh_map_list"):
		map_metadata_editor._refresh_map_list()
