@tool
extends Control

## Main editor panel for The Sparkling Farce content editor
## Displays a tabbed interface for editing different types of content

const CharacterEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/character_editor.tscn")
const ClassEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/class_editor.tscn")
const ItemEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/item_editor.tscn")
const AbilityEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/ability_editor.tscn")
const DialogueEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/dialogue_editor.tscn")
const BattleEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/battle_editor.tscn")

var character_editor: Control
var class_editor: Control
var item_editor: Control
var ability_editor: Control
var dialogue_editor: Control
var battle_editor: Control

var tab_container: TabContainer


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

	# Make tabs more visible with custom theme overrides
	tab_container.add_theme_font_size_override("font_size", 14)
	tab_container.add_theme_constant_override("side_margin", 10)

	# Connect to tab changed signal for debugging
	tab_container.tab_changed.connect(_on_tab_changed)

	# Create editor tabs - Overview first so it shows by default
	_create_overview_tab()
	_create_class_editor_tab()
	_create_character_editor_tab()
	_create_item_editor_tab()
	_create_ability_editor_tab()
	_create_dialogue_editor_tab()
	_create_battle_editor_tab()

	# Debug: Log main panel and TabContainer sizing
	call_deferred("_debug_main_panel_sizes")


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


func _create_battle_editor_tab() -> void:
	battle_editor = BattleEditorScene.instantiate()
	tab_container.add_child(battle_editor)


func _on_tab_changed(tab_index: int) -> void:
	pass


func _debug_main_panel_sizes() -> void:
	print("=== MAIN PANEL DEBUG ===")
	print("Main panel size: ", size)
	print("Main panel custom_minimum_size: ", custom_minimum_size)
	print("Main panel anchors: (", anchor_left, ", ", anchor_top, ", ", anchor_right, ", ", anchor_bottom, ")")
	print("Main panel offsets: (", offset_left, ", ", offset_top, ", ", offset_right, ", ", offset_bottom, ")")
	print("Main panel size_flags: h=", size_flags_horizontal, " v=", size_flags_vertical)
	print("Main panel parent: ", get_parent().get_class() if get_parent() else "null")
	if get_parent():
		print("Main panel parent size: ", get_parent().size)
	print("TabContainer size: ", tab_container.size if tab_container else "null")
	print("TabContainer custom_minimum_size: ", tab_container.custom_minimum_size if tab_container else "null")
	print("TabContainer anchors: (", tab_container.anchor_left if tab_container else "null", ", ", tab_container.anchor_top if tab_container else "null", ", ", tab_container.anchor_right if tab_container else "null", ", ", tab_container.anchor_bottom if tab_container else "null", ")")
	print("TabContainer use_hidden_tabs_for_min_size: ", tab_container.use_hidden_tabs_for_min_size if tab_container else "null")
	print("========================")
