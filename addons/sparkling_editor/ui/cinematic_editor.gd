@tool
extends JsonEditorBase

## Visual Cinematic Editor
## Provides a visual interface for editing cinematic JSON files with:
## - Command list with drag-to-reorder
## - Type-specific command inspector
## - Validation before save
## - Character picker for dialog commands

const DialogLinePopupScript: GDScript = preload("res://addons/sparkling_editor/ui/components/dialog_line_popup.gd")

# Command type definitions with parameter schemas
# Each command type defines its parameters and their types for the inspector
const COMMAND_DEFINITIONS: Dictionary = {
	"wait": {
		"description": "Pause execution for a duration",
		"icon": "Timer",
		"params": {
			"duration": {"type": "float", "default": 1.0, "min": 0.0, "max": 60.0, "hint": "Seconds to wait"}
		}
	},
	"dialog_line": {
		"description": "Show a single dialog line with character portrait",
		"icon": "RichTextLabel",
		"params": {
			"character_id": {"type": "character", "default": "", "hint": "Character UID"},
			"text": {"type": "text", "default": "", "hint": "Variables: {player_name}, {char:id}, {gold}, {party_count}, {flag:name}, {var:key}"},
			"emotion": {"type": "enum", "default": "neutral", "options": ["neutral", "happy", "sad", "angry", "worried", "surprised", "determined", "thinking"], "hint": "Character emotion"}
		}
	},
	"show_dialog": {
		"description": "Show dialog from a DialogueData resource",
		"icon": "AcceptDialog",
		"params": {
			"dialogue_id": {"type": "string", "default": "", "hint": "DialogueData resource ID"}
		}
	},
	"move_entity": {
		"description": "Move an entity along a path",
		"icon": "MoveLocal",
		"has_target": true,
		"params": {
			"path": {"type": "path", "default": [], "hint": "Array of [x, y] grid positions"},
			"speed": {"type": "float", "default": 3.0, "min": 0.5, "max": 20.0, "hint": "Movement speed"},
			"wait": {"type": "bool", "default": true, "hint": "Wait for movement to complete"}
		}
	},
	"set_facing": {
		"description": "Set entity facing direction",
		"icon": "MeshTexture",
		"has_target": true,
		"params": {
			"direction": {"type": "enum", "default": "down", "options": ["up", "down", "left", "right"], "hint": "Facing direction"}
		}
	},
	"play_animation": {
		"description": "Play an animation on an entity",
		"icon": "Animation",
		"has_target": true,
		"params": {
			"animation": {"type": "string", "default": "", "hint": "Animation name"},
			"wait": {"type": "bool", "default": false, "hint": "Wait for animation to complete"}
		}
	},
	"camera_move": {
		"description": "Move camera to a position",
		"icon": "Camera2D",
		"params": {
			"target_pos": {"type": "vector2", "default": [0, 0], "hint": "Target position"},
			"speed": {"type": "float", "default": 2.0, "min": 0.5, "max": 20.0, "hint": "Camera speed (tiles/sec)"},
			"wait": {"type": "bool", "default": true, "hint": "Wait for movement to complete"},
			"is_grid": {"type": "bool", "default": false, "hint": "Position is in grid coordinates"}
		}
	},
	"camera_follow": {
		"description": "Make camera follow an entity",
		"icon": "ViewportTexture",
		"has_target": true,
		"params": {
			"wait": {"type": "bool", "default": false, "hint": "Wait for initial movement"},
			"duration": {"type": "float", "default": 0.5, "min": 0.0, "max": 5.0, "hint": "Transition duration"},
			"continuous": {"type": "bool", "default": true, "hint": "Keep following until stopped"},
			"speed": {"type": "float", "default": 8.0, "min": 1.0, "max": 20.0, "hint": "Follow speed"}
		}
	},
	"camera_shake": {
		"description": "Shake the camera for dramatic effect",
		"icon": "AudioStreamRandomizer",
		"params": {
			"intensity": {"type": "float", "default": 2.0, "min": 0.5, "max": 20.0, "hint": "Shake intensity (pixels)"},
			"duration": {"type": "float", "default": 0.5, "min": 0.1, "max": 5.0, "hint": "Shake duration"},
			"frequency": {"type": "float", "default": 30.0, "min": 5.0, "max": 60.0, "hint": "Shake frequency"},
			"wait": {"type": "bool", "default": false, "hint": "Wait for shake to complete"}
		}
	},
	"fade_screen": {
		"description": "Fade screen in or out",
		"icon": "ColorRect",
		"params": {
			"fade_type": {"type": "enum", "default": "out", "options": ["in", "out"], "hint": "Fade direction"},
			"duration": {"type": "float", "default": 1.0, "min": 0.1, "max": 5.0, "hint": "Fade duration"},
			"color": {"type": "color", "default": [0, 0, 0, 1], "hint": "Fade color"}
		}
	},
	"play_sound": {
		"description": "Play a sound effect",
		"icon": "AudioStreamPlayer",
		"params": {
			"sound_id": {"type": "string", "default": "", "hint": "Sound effect ID"}
		}
	},
	"play_music": {
		"description": "Play background music",
		"icon": "AudioStreamPlayer2D",
		"params": {
			"music_id": {"type": "string", "default": "", "hint": "Music track ID"},
			"fade_duration": {"type": "float", "default": 0.5, "min": 0.0, "max": 5.0, "hint": "Fade-in duration"}
		}
	},
	"spawn_entity": {
		"description": "Spawn an entity at a position",
		"icon": "Node2D",
		"params": {
			"actor_id": {"type": "string", "default": "", "hint": "Actor ID to assign"},
			"position": {"type": "vector2", "default": [0, 0], "hint": "Spawn position (grid)"},
			"facing": {"type": "enum", "default": "down", "options": ["up", "down", "left", "right"], "hint": "Initial facing"},
			"character_id": {"type": "character", "default": "", "hint": "CharacterData to spawn"}
		}
	},
	"despawn_entity": {
		"description": "Remove an entity from the scene",
		"icon": "Remove",
		"has_target": true,
		"params": {
			"fade": {"type": "float", "default": 0.0, "min": 0.0, "max": 3.0, "hint": "Fade out duration (0 = instant)"}
		}
	},
	"set_variable": {
		"description": "Set a game state variable or flag",
		"icon": "PinJoint2D",
		"params": {
			"variable": {"type": "string", "default": "", "hint": "Variable name"},
			"value": {"type": "variant", "default": true, "hint": "Value to set (true for flags)"}
		}
	},
	"open_shop": {
		"description": "Open a shop interface (weapon/item shop, church, crafter)",
		"icon": "ShoppingCart",
		"params": {
			"shop_id": {"type": "shop", "default": "", "hint": "ShopData resource ID"}
		}
	}
}

# Default category assignments for commands without explicit category metadata
const DEFAULT_CATEGORIES: Dictionary = {
	"dialog_line": "Dialog",
	"show_dialog": "Dialog",
	"move_entity": "Entity",
	"set_facing": "Entity",
	"play_animation": "Entity",
	"spawn_entity": "Entity",
	"despawn_entity": "Entity",
	"camera_move": "Camera",
	"camera_follow": "Camera",
	"camera_shake": "Camera",
	"fade_screen": "Screen",
	"wait": "Screen",
	"play_sound": "Audio",
	"play_music": "Audio",
	"set_variable": "Game State",
	"open_shop": "Interaction"
}


## Get merged command definitions (hardcoded + dynamic from executor scripts)
## Dynamic definitions take priority over hardcoded ones
static func _get_merged_command_definitions() -> Dictionary:
	var merged: Dictionary = COMMAND_DEFINITIONS.duplicate(true)

	# Scan executor scripts directly for metadata (works reliably in @tool scripts)
	# This approach doesn't depend on CinematicsManager being initialized
	var executor_dir: String = "res://core/systems/cinematic_commands/"
	var dir: DirAccess = DirAccess.open(executor_dir)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with("_executor.gd") and not dir.current_is_dir():
				var script_path: String = executor_dir + file_name
				var script: GDScript = load(script_path) as GDScript
				if script:
					# Extract command type from filename (e.g., "add_party_member_executor.gd" -> "add_party_member")
					var cmd_type: String = file_name.replace("_executor.gd", "")

					# Instantiate to get metadata
					var executor: RefCounted = script.new()
					if executor.has_method("get_editor_metadata"):
						var metadata: Dictionary = executor.get_editor_metadata()
						if not metadata.is_empty():
							if cmd_type in merged:
								# Merge: overlay dynamic onto hardcoded
								var base: Dictionary = merged[cmd_type]
								for key: String in metadata.keys():
									base[key] = metadata[key]
							else:
								# New command type from executor
								merged[cmd_type] = metadata
			file_name = dir.get_next()
		dir.list_dir_end()

	return merged


## Build categories dictionary from command definitions
## Commands provide their own category via metadata, or use DEFAULT_CATEGORIES fallback
static func _build_categories_from_definitions(definitions: Dictionary) -> Dictionary:
	var categories: Dictionary = {}

	for cmd_type: String in definitions:
		var def: Dictionary = definitions[cmd_type]
		var category: String = ""

		# Get category from metadata, or fallback to default
		if "category" in def:
			category = def.category
		elif cmd_type in DEFAULT_CATEGORIES:
			category = DEFAULT_CATEGORIES[cmd_type]
		else:
			category = "Other"

		if category not in categories:
			categories[category] = []
		categories[category].append(cmd_type)

	# Sort categories in a sensible order
	var ordered: Dictionary = {}
	var preferred_order: Array = ["Dialog", "Entity", "Camera", "Screen", "Audio", "Game State", "Interaction", "Party"]
	for cat: String in preferred_order:
		if cat in categories:
			ordered[cat] = categories[cat]
			categories.erase(cat)
	# Add any remaining categories at the end
	for cat: String in categories:
		ordered[cat] = categories[cat]

	return ordered


# UI Components - Left panel (file list)
var cinematic_list: ItemList
var refresh_button: Button
var create_button: Button
var delete_button: Button

# UI Components - Center panel (command list)
var command_list: ItemList
var add_command_button: MenuButton
var delete_command_button: Button
var move_up_button: Button
var move_down_button: Button
var duplicate_button: Button

# UI Components - Right panel (inspector)
var inspector_scroll: ScrollContainer
var inspector_panel: VBoxContainer
var inspector_fields: Dictionary = {}  # param_name -> Control
var target_field: LineEdit  # For commands with target (actor_id)

# UI Components - Metadata
var cinematic_id_edit: LineEdit
var cinematic_id_lock_btn: Button
var cinematic_name_edit: LineEdit
var description_edit: TextEdit
var can_skip_check: CheckBox
var disable_input_check: CheckBox
var save_button: Button

# Quick Add Dialog popup
var dialog_line_popup: Window

# Current state
var cinematics: Array[Dictionary] = []  # [{path, mod_id, name}]
var current_cinematic_path: String = ""
var current_cinematic_data: Dictionary = {}
var selected_command_index: int = -1
var _updating_ui: bool = false

# Track if ID should auto-generate from name (unlocked = auto-generate)
var _id_is_locked: bool = false

# Character, NPC, and Shop caches for pickers
var _characters: Array[Resource] = []
var _npcs: Array[Resource] = []
var _shops: Array[Resource] = []


func _ready() -> void:
	resource_type_name = "Cinematic"
	resource_dir_name = "cinematics"
	_refresh_characters()
	_setup_ui()
	_refresh_cinematic_list()

	# Connect to EditorEventBus for mod reload notifications
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	if event_bus:
		if not event_bus.mods_reloaded.is_connected(_on_mods_reloaded):
			event_bus.mods_reloaded.connect(_on_mods_reloaded)
		# Also refresh when characters are saved/created
		if not event_bus.resource_saved.is_connected(_on_resource_changed):
			event_bus.resource_saved.connect(_on_resource_changed)
		if not event_bus.resource_created.is_connected(_on_resource_changed):
			event_bus.resource_created.connect(_on_resource_changed)


## Called when mods are reloaded via Refresh Mods button
func _on_mods_reloaded() -> void:
	_refresh_characters()
	_refresh_cinematic_list()


## Called when any resource is saved or created
func _on_resource_changed(resource_type: String, _resource_id: String, _resource: Resource) -> void:
	# Refresh characters/NPCs if either was modified
	if resource_type in ["character", "characters", "npc", "npcs"]:
		_refresh_characters()


func _refresh_characters() -> void:
	_characters.clear()
	_npcs.clear()
	_shops.clear()
	if ModLoader and ModLoader.registry:
		_characters = ModLoader.registry.get_all_resources("character")
		_npcs = ModLoader.registry.get_all_resources("npc")
		_shops = ModLoader.registry.get_all_resources("shop")


func _setup_ui() -> void:
	var main_hsplit: HSplitContainer = HSplitContainer.new()
	main_hsplit.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_hsplit)

	# Left panel - File list
	_setup_file_list_panel(main_hsplit)

	# Center split - Command list + Inspector
	var center_hsplit: HSplitContainer = HSplitContainer.new()
	center_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hsplit.add_child(center_hsplit)

	# Center panel - Command list
	_setup_command_list_panel(center_hsplit)

	# Right panel - Inspector
	_setup_inspector_panel(center_hsplit)


func _setup_file_list_panel(parent: HSplitContainer) -> void:
	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 200
	left_panel.add_theme_constant_override("separation", 4)
	parent.add_child(left_panel)

	# Header
	var header: HBoxContainer = HBoxContainer.new()
	left_panel.add_child(header)

	var title: Label = Label.new()
	title.text = "Cinematics"
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)

	header.add_spacer(false)

	refresh_button = Button.new()
	refresh_button.text = "R"
	refresh_button.tooltip_text = "Refresh list"
	refresh_button.pressed.connect(_refresh_cinematic_list)
	header.add_child(refresh_button)

	# File list
	cinematic_list = ItemList.new()
	cinematic_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cinematic_list.item_selected.connect(_on_cinematic_selected)
	cinematic_list.allow_reselect = true
	left_panel.add_child(cinematic_list)

	# Buttons
	var btn_row: HBoxContainer = HBoxContainer.new()
	left_panel.add_child(btn_row)

	create_button = Button.new()
	create_button.text = "New"
	create_button.tooltip_text = "Create a new cinematic. Tip: Name it 'opening_cinematic' to replace the game's opening sequence."
	create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_button.pressed.connect(_on_create_new)
	btn_row.add_child(create_button)

	delete_button = Button.new()
	delete_button.text = "Delete"
	delete_button.disabled = true
	delete_button.pressed.connect(_on_delete_cinematic)
	btn_row.add_child(delete_button)


func _setup_command_list_panel(parent: HSplitContainer) -> void:
	var center_panel: VBoxContainer = VBoxContainer.new()
	center_panel.custom_minimum_size.x = 280
	center_panel.add_theme_constant_override("separation", 4)
	parent.add_child(center_panel)

	# Metadata section
	_setup_metadata_section(center_panel)

	# Command list header
	var cmd_header: HBoxContainer = HBoxContainer.new()
	cmd_header.add_theme_constant_override("separation", 4)
	center_panel.add_child(cmd_header)

	var cmd_label: Label = Label.new()
	cmd_label.text = "Commands"
	cmd_label.add_theme_font_size_override("font_size", 16)
	cmd_header.add_child(cmd_label)

	cmd_header.add_spacer(false)

	# Add command dropdown
	add_command_button = MenuButton.new()
	add_command_button.text = "+ Add"
	add_command_button.tooltip_text = "Add a new command"
	# Rebuild menu dynamically each time it's shown (ensures CinematicsManager commands are loaded)
	add_command_button.get_popup().about_to_popup.connect(_setup_add_command_menu)
	cmd_header.add_child(add_command_button)

	# Quick Add Dialog button
	var quick_dialog_btn: Button = Button.new()
	quick_dialog_btn.text = "Dialog"
	quick_dialog_btn.tooltip_text = "Quick Add Dialog Line"
	quick_dialog_btn.pressed.connect(_on_quick_add_dialog)
	cmd_header.add_child(quick_dialog_btn)

	# Command list
	command_list = ItemList.new()
	command_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	command_list.item_selected.connect(_on_command_selected)
	command_list.allow_reselect = true
	center_panel.add_child(command_list)

	# Command action buttons
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 4)
	center_panel.add_child(action_row)

	move_up_button = Button.new()
	move_up_button.text = "Up"
	move_up_button.tooltip_text = "Move command up"
	move_up_button.disabled = true
	move_up_button.pressed.connect(_on_move_up)
	action_row.add_child(move_up_button)

	move_down_button = Button.new()
	move_down_button.text = "Down"
	move_down_button.tooltip_text = "Move command down"
	move_down_button.disabled = true
	move_down_button.pressed.connect(_on_move_down)
	action_row.add_child(move_down_button)

	duplicate_button = Button.new()
	duplicate_button.text = "Dup"
	duplicate_button.tooltip_text = "Duplicate command"
	duplicate_button.disabled = true
	duplicate_button.pressed.connect(_on_duplicate_command)
	action_row.add_child(duplicate_button)

	action_row.add_spacer(false)

	delete_command_button = Button.new()
	delete_command_button.text = "Delete"
	delete_command_button.disabled = true
	delete_command_button.pressed.connect(_on_delete_command)
	action_row.add_child(delete_command_button)

	# Error panel
	var err_panel: PanelContainer = create_error_panel()
	center_panel.add_child(err_panel)

	# Save button
	save_button = Button.new()
	save_button.text = "Save Cinematic"
	save_button.pressed.connect(_on_save)
	center_panel.add_child(save_button)


func _setup_metadata_section(parent: VBoxContainer) -> void:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	parent.add_child(section)

	# Name row (moved above ID so name drives ID auto-generation)
	var name_row: HBoxContainer = HBoxContainer.new()
	section.add_child(name_row)

	var name_label: Label = Label.new()
	name_label.text = "Name:"
	name_label.custom_minimum_size.x = 50
	name_row.add_child(name_label)

	cinematic_name_edit = LineEdit.new()
	cinematic_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cinematic_name_edit.placeholder_text = "Display name"
	cinematic_name_edit.text_changed.connect(_on_cinematic_name_changed)
	name_row.add_child(cinematic_name_edit)

	# ID row
	var id_row: HBoxContainer = HBoxContainer.new()
	section.add_child(id_row)

	var id_label: Label = Label.new()
	id_label.text = "ID:"
	id_label.custom_minimum_size.x = 50
	id_row.add_child(id_label)

	cinematic_id_edit = LineEdit.new()
	cinematic_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cinematic_id_edit.placeholder_text = "(auto-generated from name)"
	cinematic_id_edit.tooltip_text = "Unique ID for this cinematic. Special IDs:\n• 'opening_cinematic' - Becomes the game's opening sequence"
	cinematic_id_edit.text_changed.connect(_on_cinematic_id_manually_changed)
	id_row.add_child(cinematic_id_edit)

	cinematic_id_lock_btn = Button.new()
	cinematic_id_lock_btn.text = "Unlock"
	cinematic_id_lock_btn.tooltip_text = "Lock ID to prevent auto-generation"
	cinematic_id_lock_btn.custom_minimum_size.x = 60
	cinematic_id_lock_btn.pressed.connect(_on_id_lock_toggled)
	id_row.add_child(cinematic_id_lock_btn)

	# Options row
	var opt_row: HBoxContainer = HBoxContainer.new()
	opt_row.add_theme_constant_override("separation", 12)
	section.add_child(opt_row)

	can_skip_check = CheckBox.new()
	can_skip_check.text = "Can Skip"
	can_skip_check.button_pressed = true
	opt_row.add_child(can_skip_check)

	disable_input_check = CheckBox.new()
	disable_input_check.text = "Disable Input"
	disable_input_check.button_pressed = true
	opt_row.add_child(disable_input_check)

	# Separator
	var sep: HSeparator = HSeparator.new()
	section.add_child(sep)


func _setup_inspector_panel(parent: HSplitContainer) -> void:
	var right_panel: VBoxContainer = VBoxContainer.new()
	right_panel.custom_minimum_size.x = 320
	right_panel.add_theme_constant_override("separation", 4)
	parent.add_child(right_panel)

	# Header
	var header: Label = Label.new()
	header.text = "Command Inspector"
	header.add_theme_font_size_override("font_size", 16)
	right_panel.add_child(header)

	var sep: HSeparator = HSeparator.new()
	right_panel.add_child(sep)

	# Scrollable inspector
	inspector_scroll = ScrollContainer.new()
	inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(inspector_scroll)

	inspector_panel = VBoxContainer.new()
	inspector_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_panel.add_theme_constant_override("separation", 8)
	inspector_scroll.add_child(inspector_panel)

	# Placeholder text
	var placeholder: Label = Label.new()
	placeholder.name = "Placeholder"
	placeholder.text = "Select a command to edit its parameters"
	placeholder.add_theme_color_override("font_color", SparklingEditorUtils.get_disabled_color())
	inspector_panel.add_child(placeholder)


func _setup_add_command_menu() -> void:
	var popup: PopupMenu = add_command_button.get_popup()
	popup.clear()

	# Disconnect previous signal connection if any (menu rebuilds dynamically)
	if popup.id_pressed.is_connected(_on_add_command_menu_selected):
		popup.id_pressed.disconnect(_on_add_command_menu_selected)

	# Get merged definitions (hardcoded + dynamic from executors)
	var definitions: Dictionary = _get_merged_command_definitions()

	# Build categories dynamically from definitions
	var categories: Dictionary = _build_categories_from_definitions(definitions)

	var idx: int = 0
	for category: String in categories.keys():
		if idx > 0:
			popup.add_separator()
		popup.add_separator(category)
		for cmd_type: String in categories[category]:
			if cmd_type in definitions:
				var def: Dictionary = definitions[cmd_type]
				var desc: String = def.get("description", cmd_type)
				popup.add_item(cmd_type + " - " + desc.substr(0, 30), idx)
				popup.set_item_metadata(idx, cmd_type)
				idx += 1

	popup.id_pressed.connect(_on_add_command_menu_selected)


func _on_add_command_menu_selected(id: int) -> void:
	var popup: PopupMenu = add_command_button.get_popup()
	var cmd_type: String = popup.get_item_metadata(id)
	if not cmd_type.is_empty():
		_add_new_command(cmd_type)


func _add_new_command(cmd_type: String) -> void:
	if "commands" not in current_cinematic_data:
		current_cinematic_data["commands"] = []

	var commands: Array = current_cinematic_data["commands"]

	# Build new command from definition (merged hardcoded + dynamic)
	var new_cmd: Dictionary = {"type": cmd_type, "params": {}}
	var definitions: Dictionary = _get_merged_command_definitions()

	if cmd_type in definitions:
		var def: Dictionary = definitions[cmd_type]
		if "has_target" in def and def.has_target:
			new_cmd["target"] = ""
		if "params" in def:
			for param_name: String in def.params.keys():
				var param_def: Dictionary = def.params[param_name]
				new_cmd["params"][param_name] = param_def.get("default", "")

	# Insert after current selection or at end
	var insert_idx: int = selected_command_index + 1 if selected_command_index >= 0 else commands.size()
	commands.insert(insert_idx, new_cmd)

	_rebuild_command_list()
	_select_command(insert_idx)
	is_dirty = true


## Public refresh method for standard editor interface
func refresh() -> void:
	_refresh_cinematic_list()


func _refresh_cinematic_list() -> void:
	cinematics.clear()
	cinematic_list.clear()

	# Scan mods
	var mods_dir: String = "res://mods/"
	var dir: DirAccess = DirAccess.open(mods_dir)
	if not dir:
		return

	dir.list_dir_begin()
	var mod_name: String = dir.get_next()
	while mod_name != "":
		if dir.current_is_dir() and not mod_name.begins_with("."):
			_scan_mod_cinematics(mods_dir + mod_name)
		mod_name = dir.get_next()
	dir.list_dir_end()

	# Sort
	cinematics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.mod_id + "/" + a.name < b.mod_id + "/" + b.name
	)

	# Populate list
	for entry: Dictionary in cinematics:
		cinematic_list.add_item("[%s] %s" % [entry.mod_id, entry.name])

	delete_button.disabled = true


func _scan_mod_cinematics(mod_path: String) -> void:
	var cinematics_path: String = mod_path + "/data/cinematics/"
	var dir: DirAccess = DirAccess.open(cinematics_path)
	if not dir:
		return

	var mod_id: String = mod_path.get_file()
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			cinematics.append({
				"path": cinematics_path + file_name,
				"mod_id": mod_id,
				"name": file_name.get_basename()
			})
		file_name = dir.get_next()
	dir.list_dir_end()


func _on_cinematic_selected(index: int) -> void:
	if index < 0 or index >= cinematics.size():
		return

	var entry: Dictionary = cinematics[index]
	_load_cinematic(entry.path)
	delete_button.disabled = false


func _load_cinematic(path: String) -> void:
	var data: Dictionary = load_json_file(path)
	if data.is_empty():
		return

	current_cinematic_path = path
	current_cinematic_data = data
	selected_command_index = -1
	is_dirty = false

	_populate_metadata()
	_rebuild_command_list()
	_clear_inspector()
	_hide_errors()


func _populate_metadata() -> void:
	_updating_ui = true
	cinematic_name_edit.text = current_cinematic_data.get("cinematic_name", "")
	cinematic_id_edit.text = current_cinematic_data.get("cinematic_id", "")
	can_skip_check.button_pressed = current_cinematic_data.get("can_skip", true)
	disable_input_check.button_pressed = current_cinematic_data.get("disable_player_input", true)

	# Determine if ID was manually set (different from auto-generated)
	var expected_auto_id: String = SparklingEditorUtils.generate_id_from_name(current_cinematic_data.get("cinematic_name", ""))
	var current_id: String = current_cinematic_data.get("cinematic_id", "")
	_id_is_locked = (current_id != expected_auto_id) and not current_id.is_empty()
	_update_lock_button()

	_updating_ui = false


func _rebuild_command_list() -> void:
	command_list.clear()
	var commands: Array = current_cinematic_data.get("commands", [])

	for i: int in range(commands.size()):
		var cmd: Dictionary = commands[i]
		var cmd_type: String = cmd.get("type", "unknown")
		var display: String = _format_command_display(cmd, i)
		command_list.add_item(display)

		# Color code by type
		var color: Color = _get_command_color(cmd_type)
		command_list.set_item_custom_fg_color(i, color)

	_update_command_buttons()


func _format_command_display(cmd: Dictionary, index: int) -> String:
	var cmd_type: String = cmd.get("type", "?")
	var params: Dictionary = cmd.get("params", {})
	var target: String = cmd.get("target", "")

	var summary: String = ""
	match cmd_type:
		"dialog_line":
			var char_id: String = params.get("character_id", "")
			var text: String = params.get("text", "")
			var char_name: String = _get_character_name(char_id)
			if text.length() > 25:
				text = text.substr(0, 25) + "..."
			summary = "%s: \"%s\"" % [char_name, text]
		"wait":
			summary = "%.1fs" % params.get("duration", 1.0)
		"fade_screen":
			summary = "fade %s (%.1fs)" % [params.get("fade_type", "out"), params.get("duration", 1.0)]
		"camera_shake":
			summary = "intensity: %.1f" % params.get("intensity", 2.0)
		"move_entity":
			summary = target if not target.is_empty() else "(no target)"
		"set_facing":
			summary = "%s -> %s" % [target, params.get("direction", "?")]
		"play_sound", "play_music":
			var id_key: String = "sound_id" if cmd_type == "play_sound" else "music_id"
			summary = params.get(id_key, "(none)")
		"set_variable":
			summary = params.get("variable", "(none)")
		"spawn_entity":
			summary = params.get("actor_id", "(no actor)")
		"despawn_entity":
			summary = target if not target.is_empty() else "(no target)"
		_:
			if not target.is_empty():
				summary = target

	if summary.is_empty():
		return "%d. %s" % [index + 1, cmd_type]
	return "%d. %s: %s" % [index + 1, cmd_type, summary]


func _get_command_color(cmd_type: String) -> Color:
	match cmd_type:
		"dialog_line", "show_dialog":
			return Color(0.4, 0.8, 0.4)  # Green
		"move_entity", "set_facing", "play_animation":
			return Color(0.4, 0.6, 1.0)  # Blue
		"camera_move", "camera_follow", "camera_shake":
			return Color(0.9, 0.7, 0.3)  # Orange
		"fade_screen", "wait":
			return Color(0.7, 0.5, 0.9)  # Purple
		"play_sound", "play_music":
			return Color(0.3, 0.8, 0.8)  # Cyan
		"spawn_entity", "despawn_entity":
			return Color(0.8, 0.4, 0.4)  # Red
		"set_variable":
			return Color(0.6, 0.6, 0.6)  # Gray
		_:
			return Color(1.0, 1.0, 1.0)


func _get_character_name(character_uid: String) -> String:
	if character_uid.is_empty():
		return "[?]"
	for char_res: Resource in _characters:
		# Use get() for safe property access in editor context
		var res_uid: String = ""
		var res_name: String = ""
		if "character_uid" in char_res:
			res_uid = str(char_res.get("character_uid"))
		if "character_name" in char_res:
			res_name = str(char_res.get("character_name"))
		if res_uid == character_uid:
			return res_name if not res_name.is_empty() else "[" + character_uid + "]"
	return "[" + character_uid + "]"


func _on_command_selected(index: int) -> void:
	selected_command_index = index
	_update_command_buttons()
	_build_inspector_for_command(index)


func _select_command(index: int) -> void:
	if index >= 0 and index < command_list.item_count:
		command_list.select(index)
		_on_command_selected(index)


func _update_command_buttons() -> void:
	var has_selection: bool = selected_command_index >= 0
	var commands: Array = current_cinematic_data.get("commands", [])

	delete_command_button.disabled = not has_selection
	duplicate_button.disabled = not has_selection
	move_up_button.disabled = not has_selection or selected_command_index <= 0
	move_down_button.disabled = not has_selection or selected_command_index >= commands.size() - 1


func _clear_inspector() -> void:
	for child: Node in inspector_panel.get_children():
		child.queue_free()
	inspector_fields.clear()
	target_field = null

	# Re-add placeholder
	var placeholder: Label = Label.new()
	placeholder.name = "Placeholder"
	placeholder.text = "Select a command to edit its parameters"
	placeholder.add_theme_color_override("font_color", SparklingEditorUtils.get_disabled_color())
	inspector_panel.add_child(placeholder)


func _build_inspector_for_command(index: int) -> void:
	# Clear existing
	for child: Node in inspector_panel.get_children():
		child.queue_free()
	inspector_fields.clear()
	target_field = null

	var commands: Array = current_cinematic_data.get("commands", [])
	if index < 0 or index >= commands.size():
		_clear_inspector()
		return

	var cmd: Dictionary = commands[index]
	var cmd_type: String = cmd.get("type", "")
	var params: Dictionary = cmd.get("params", {})

	# Command type header
	var type_label: Label = Label.new()
	type_label.text = cmd_type.to_upper()
	type_label.add_theme_font_size_override("font_size", 16)
	type_label.add_theme_color_override("font_color", _get_command_color(cmd_type))
	inspector_panel.add_child(type_label)

	# Description (from merged definitions)
	var definitions: Dictionary = _get_merged_command_definitions()
	if cmd_type in definitions and "description" in definitions[cmd_type]:
		var desc_label: Label = Label.new()
		desc_label.text = definitions[cmd_type].description
		desc_label.add_theme_color_override("font_color", SparklingEditorUtils.get_disabled_color())
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inspector_panel.add_child(desc_label)

	var sep: HSeparator = HSeparator.new()
	inspector_panel.add_child(sep)

	# Target field (if applicable)
	if "target" in cmd:
		var target_row: HBoxContainer = HBoxContainer.new()
		inspector_panel.add_child(target_row)

		var target_label: Label = Label.new()
		target_label.text = "Target (Actor ID):"
		target_label.custom_minimum_size.x = 130
		target_row.add_child(target_label)

		target_field = LineEdit.new()
		target_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		target_field.text = cmd.get("target", "")
		target_field.placeholder_text = "actor_id"
		target_field.text_changed.connect(_on_target_changed)
		target_row.add_child(target_field)

	# Build parameter fields based on definition (using merged definitions)
	if cmd_type in definitions and "params" in definitions[cmd_type]:
		var def: Dictionary = definitions[cmd_type]
		for param_name: String in def.params.keys():
			var param_def: Dictionary = def.params[param_name]
			var current_value: Variant = params.get(param_name, param_def.get("default", ""))
			_create_param_field(param_name, param_def, current_value)
	else:
		# Unknown command type - show raw JSON
		var raw_label: Label = Label.new()
		raw_label.text = "Raw Parameters (unknown command type):"
		inspector_panel.add_child(raw_label)

		var raw_edit: TextEdit = TextEdit.new()
		raw_edit.custom_minimum_size.y = 100
		raw_edit.text = JSON.stringify(params, "  ")
		inspector_panel.add_child(raw_edit)


func _create_param_field(param_name: String, param_def: Dictionary, current_value: Variant) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	inspector_panel.add_child(row)

	var label: Label = Label.new()
	label.text = param_name.replace("_", " ").capitalize() + ":"
	label.custom_minimum_size.x = 130
	label.tooltip_text = param_def.get("hint", "")
	row.add_child(label)

	var param_type: String = param_def.get("type", "string")
	var control: Control

	match param_type:
		"float":
			var spin: SpinBox = SpinBox.new()
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.min_value = param_def.get("min", 0.0)
			spin.max_value = param_def.get("max", 100.0)
			spin.step = 0.1
			spin.value = float(current_value) if current_value != null else param_def.default
			spin.value_changed.connect(_on_param_changed.bind(param_name))
			control = spin

		"bool":
			var check: CheckBox = CheckBox.new()
			check.button_pressed = bool(current_value) if current_value != null else param_def.default
			check.toggled.connect(_on_param_changed.bind(param_name))
			control = check

		"enum":
			var option: OptionButton = OptionButton.new()
			option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var options: Array = param_def.get("options", [])
			for i: int in range(options.size()):
				option.add_item(options[i])
				if options[i] == str(current_value):
					option.select(i)
			option.item_selected.connect(_on_enum_changed.bind(param_name, options))
			control = option

		"character":
			var char_btn: OptionButton = OptionButton.new()
			char_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			char_btn.add_item("(None)", 0)
			char_btn.set_item_metadata(0, {"type": "none", "id": ""})
			var selected_idx: int = 0
			var item_idx: int = 1

			# Add characters first
			for i: int in range(_characters.size()):
				var char_res: Resource = _characters[i]
				if char_res:
					# Use get() for safe property access in editor context
					var display_name: String = SparklingEditorUtils.get_resource_display_name_with_mod(char_res, "character_name")
					# Get character_uid - try direct access, then get(), then fallback to filename
					var char_uid: String = ""
					if char_res is CharacterData:
						char_uid = (char_res as CharacterData).character_uid
					if char_uid.is_empty() and char_res.get("character_uid") != null:
						char_uid = str(char_res.get("character_uid"))
					if char_uid.is_empty():
						# Fallback: use filename as identifier (resource ID)
						char_uid = char_res.resource_path.get_file().get_basename()
					char_btn.add_item(display_name, item_idx)
					char_btn.set_item_metadata(item_idx, {"type": "character", "id": char_uid})
					if char_uid == str(current_value):
						selected_idx = item_idx
					item_idx += 1

			# Add NPCs (with visual separator via different format)
			for i: int in range(_npcs.size()):
				var npc_res: Resource = _npcs[i]
				if npc_res:
					# Get display name with fallbacks for different loading states
					var display_name: String = ""
					var npc_id: String = ""

					# Try direct property access first (works when script is attached)
					if "npc_name" in npc_res and not str(npc_res.get("npc_name")).is_empty():
						display_name = str(npc_res.get("npc_name"))
					if "npc_id" in npc_res:
						npc_id = str(npc_res.get("npc_id"))

					# Fallback to filename
					if display_name.is_empty():
						display_name = npc_res.resource_path.get_file().get_basename()
					if npc_id.is_empty():
						npc_id = npc_res.resource_path.get_file().get_basename()

					# Get source mod
					var mod_id: String = ""
					if ModLoader and ModLoader.registry:
						var resource_id: String = npc_res.resource_path.get_file().get_basename()
						mod_id = ModLoader.registry.get_resource_source(resource_id)

					var full_display: String = "[%s] %s (NPC)" % [mod_id, display_name] if not mod_id.is_empty() else "%s (NPC)" % display_name
					char_btn.add_item(full_display, item_idx)
					char_btn.set_item_metadata(item_idx, {"type": "npc", "id": npc_id})
					# Check if this NPC is selected (stored as "npc:npc_id")
					if str(current_value) == "npc:" + npc_id:
						selected_idx = item_idx
					item_idx += 1

			char_btn.select(selected_idx)
			char_btn.item_selected.connect(_on_character_or_npc_selected.bind(param_name, char_btn))
			control = char_btn

		"text":
			var text_edit: TextEdit = TextEdit.new()
			text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text_edit.custom_minimum_size.y = 60
			text_edit.text = str(current_value) if current_value != null else ""
			text_edit.placeholder_text = param_def.get("hint", "")
			text_edit.text_changed.connect(_on_text_changed.bind(param_name, text_edit))
			control = text_edit

		"vector2":
			var vec_container: HBoxContainer = HBoxContainer.new()
			vec_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var x_spin: SpinBox = SpinBox.new()
			x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			x_spin.min_value = -10000
			x_spin.max_value = 10000
			var x_label: Label = Label.new()
			x_label.text = "X:"
			vec_container.add_child(x_label)
			vec_container.add_child(x_spin)

			var y_spin: SpinBox = SpinBox.new()
			y_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			y_spin.min_value = -10000
			y_spin.max_value = 10000
			var y_label: Label = Label.new()
			y_label.text = "Y:"
			vec_container.add_child(y_label)
			vec_container.add_child(y_spin)

			# Parse current value
			if current_value is Array and current_value.size() >= 2:
				x_spin.value = current_value[0]
				y_spin.value = current_value[1]
			elif current_value is Vector2:
				x_spin.value = current_value.x
				y_spin.value = current_value.y

			x_spin.value_changed.connect(_on_vector_changed.bind(param_name, 0, y_spin))
			y_spin.value_changed.connect(_on_vector_changed.bind(param_name, 1, x_spin))

			control = vec_container

		"color":
			var color_btn: ColorPickerButton = ColorPickerButton.new()
			color_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if current_value is Array and current_value.size() >= 3:
				color_btn.color = Color(current_value[0], current_value[1], current_value[2], current_value[3] if current_value.size() > 3 else 1.0)
			elif current_value is Color:
				color_btn.color = current_value
			else:
				color_btn.color = Color.BLACK
			color_btn.color_changed.connect(_on_color_changed.bind(param_name))
			control = color_btn

		"path":
			# Path is array of positions - show as editable text for now
			var path_edit: TextEdit = TextEdit.new()
			path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			path_edit.custom_minimum_size.y = 60
			if current_value is Array:
				path_edit.text = JSON.stringify(current_value)
			else:
				path_edit.text = "[]"
			path_edit.placeholder_text = "[[x1, y1], [x2, y2], ...]"
			path_edit.text_changed.connect(_on_path_changed.bind(param_name, path_edit))
			control = path_edit

		"variant":
			# Generic value - allow string/bool/number
			var var_edit: LineEdit = LineEdit.new()
			var_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var_edit.text = str(current_value) if current_value != null else ""
			var_edit.placeholder_text = "value (string, number, or true/false)"
			var_edit.text_changed.connect(_on_variant_changed.bind(param_name))
			control = var_edit

		"shop":
			# Shop picker dropdown
			var shop_btn: OptionButton = OptionButton.new()
			shop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			shop_btn.add_item("(None)", 0)
			shop_btn.set_item_metadata(0, "")
			var selected_idx: int = 0
			var item_idx: int = 1

			for shop_res: Resource in _shops:
				if shop_res:
					var shop_id: String = ""
					var shop_name: String = ""

					if "shop_id" in shop_res:
						shop_id = str(shop_res.get("shop_id"))
					if "shop_name" in shop_res:
						shop_name = str(shop_res.get("shop_name"))

					if shop_id.is_empty():
						shop_id = shop_res.resource_path.get_file().get_basename()
					if shop_name.is_empty():
						shop_name = shop_id

					# Get source mod
					var mod_id: String = ""
					if ModLoader and ModLoader.registry:
						var resource_id: String = shop_res.resource_path.get_file().get_basename()
						mod_id = ModLoader.registry.get_resource_source(resource_id)

					var display_name: String = "[%s] %s" % [mod_id, shop_name] if not mod_id.is_empty() else shop_name
					shop_btn.add_item(display_name, item_idx)
					shop_btn.set_item_metadata(item_idx, shop_id)

					if shop_id == str(current_value):
						selected_idx = item_idx
					item_idx += 1

			shop_btn.select(selected_idx)
			shop_btn.item_selected.connect(_on_shop_selected.bind(param_name, shop_btn))
			control = shop_btn

		_:  # string and unknown types
			var line_edit: LineEdit = LineEdit.new()
			line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line_edit.text = str(current_value) if current_value != null else ""
			line_edit.placeholder_text = param_def.get("hint", "")
			line_edit.text_changed.connect(_on_param_changed.bind(param_name))
			control = line_edit

	row.add_child(control)
	inspector_fields[param_name] = control


# Parameter change handlers
func _on_target_changed(new_text: String) -> void:
	if _updating_ui or selected_command_index < 0:
		return
	var commands: Array = current_cinematic_data.get("commands", [])
	commands[selected_command_index]["target"] = new_text
	is_dirty = true
	_rebuild_command_list()
	command_list.select(selected_command_index)


func _on_param_changed(value: Variant, param_name: String) -> void:
	if _updating_ui or selected_command_index < 0:
		return
	var commands: Array = current_cinematic_data.get("commands", [])
	if "params" not in commands[selected_command_index]:
		commands[selected_command_index]["params"] = {}
	commands[selected_command_index]["params"][param_name] = value
	is_dirty = true
	_rebuild_command_list()
	command_list.select(selected_command_index)


func _on_enum_changed(index: int, param_name: String, options: Array) -> void:
	if index >= 0 and index < options.size():
		_on_param_changed(options[index], param_name)


func _on_character_or_npc_selected(index: int, param_name: String, option_btn: OptionButton) -> void:
	var metadata: Variant = option_btn.get_item_metadata(index)
	if metadata is Dictionary:
		var meta_dict: Dictionary = metadata as Dictionary
		var item_type: String = meta_dict.get("type", "none")
		var item_id: String = meta_dict.get("id", "")

		if item_type == "none" or item_id.is_empty():
			_on_param_changed("", param_name)
		elif item_type == "character":
			# Character: store the character_uid directly
			_on_param_changed(item_id, param_name)
		elif item_type == "npc":
			# NPC: store with "npc:" prefix so runtime can distinguish
			_on_param_changed("npc:" + item_id, param_name)
	else:
		_on_param_changed("", param_name)


func _on_shop_selected(index: int, param_name: String, option_btn: OptionButton) -> void:
	var shop_id: Variant = option_btn.get_item_metadata(index)
	_on_param_changed(shop_id if shop_id else "", param_name)


func _on_text_changed(param_name: String, text_edit: TextEdit) -> void:
	_on_param_changed(text_edit.text, param_name)


func _on_vector_changed(value: float, param_name: String, component: int, other_spin: SpinBox) -> void:
	var vec: Array = [0, 0]
	if component == 0:
		vec = [value, other_spin.value]
	else:
		vec = [other_spin.value, value]
	_on_param_changed(vec, param_name)


func _on_color_changed(color: Color, param_name: String) -> void:
	_on_param_changed([color.r, color.g, color.b, color.a], param_name)


func _on_path_changed(param_name: String, path_edit: TextEdit) -> void:
	var parsed: Variant = validate_json_string(path_edit.text)
	if parsed != null and parsed is Array:
		_on_param_changed(parsed, param_name)


func _on_variant_changed(new_text: String, param_name: String) -> void:
	# Try to parse as bool/number first
	var value: Variant = new_text
	if new_text.to_lower() == "true":
		value = true
	elif new_text.to_lower() == "false":
		value = false
	elif new_text.is_valid_float():
		value = new_text.to_float()
	elif new_text.is_valid_int():
		value = new_text.to_int()
	_on_param_changed(value, param_name)


# Command list actions
func _on_move_up() -> void:
	if selected_command_index <= 0:
		return
	var commands: Array = current_cinematic_data.get("commands", [])
	var cmd: Dictionary = commands[selected_command_index]
	commands.remove_at(selected_command_index)
	commands.insert(selected_command_index - 1, cmd)
	selected_command_index -= 1
	_rebuild_command_list()
	command_list.select(selected_command_index)
	is_dirty = true


func _on_move_down() -> void:
	var commands: Array = current_cinematic_data.get("commands", [])
	if selected_command_index < 0 or selected_command_index >= commands.size() - 1:
		return
	var cmd: Dictionary = commands[selected_command_index]
	commands.remove_at(selected_command_index)
	commands.insert(selected_command_index + 1, cmd)
	selected_command_index += 1
	_rebuild_command_list()
	command_list.select(selected_command_index)
	is_dirty = true


func _on_duplicate_command() -> void:
	if selected_command_index < 0:
		return
	var commands: Array = current_cinematic_data.get("commands", [])
	var cmd: Dictionary = commands[selected_command_index].duplicate(true)
	commands.insert(selected_command_index + 1, cmd)
	_rebuild_command_list()
	_select_command(selected_command_index + 1)
	is_dirty = true


func _on_delete_command() -> void:
	if selected_command_index < 0:
		return
	var commands: Array = current_cinematic_data.get("commands", [])
	commands.remove_at(selected_command_index)

	var new_selection: int = mini(selected_command_index, commands.size() - 1)
	selected_command_index = -1
	_rebuild_command_list()

	if new_selection >= 0:
		_select_command(new_selection)
	else:
		_clear_inspector()
	is_dirty = true


# Quick Add Dialog
func _on_quick_add_dialog() -> void:
	if not dialog_line_popup:
		dialog_line_popup = DialogLinePopupScript.new()
		dialog_line_popup.dialog_created.connect(_on_dialog_line_created)
		add_child(dialog_line_popup)

	dialog_line_popup.show_popup()


func _on_dialog_line_created(json_text: String) -> void:
	# Parse the JSON and add as a command
	var json: JSON = JSON.new()
	if json.parse(json_text) == OK and json.data is Dictionary:
		if "commands" not in current_cinematic_data:
			current_cinematic_data["commands"] = []

		var commands: Array = current_cinematic_data["commands"]
		var insert_idx: int = selected_command_index + 1 if selected_command_index >= 0 else commands.size()
		commands.insert(insert_idx, json.data)

		_rebuild_command_list()
		_select_command(insert_idx)
		is_dirty = true


# File operations
func _on_create_new() -> void:
	var active_mod: String = _get_active_mod()
	if active_mod.is_empty():
		_show_errors(["No active mod selected"])
		return

	var cinematics_dir: String = "res://mods/%s/data/cinematics/" % active_mod
	if not ensure_directory_exists(cinematics_dir):
		return

	# Generate unique name
	var base_name: String = "new_cinematic"
	var counter: int = 1
	var new_path: String = cinematics_dir + base_name + ".json"
	while FileAccess.file_exists(new_path):
		new_path = cinematics_dir + base_name + "_" + str(counter) + ".json"
		counter += 1

	# Use auto-generated ID from name so it starts unlocked
	var initial_name: String = "New Cinematic"
	var initial_id: String = SparklingEditorUtils.generate_id_from_name(initial_name)

	current_cinematic_data = {
		"cinematic_id": initial_id,
		"cinematic_name": initial_name,
		"description": "",
		"can_skip": true,
		"disable_player_input": true,
		"commands": []
	}

	current_cinematic_path = new_path
	_populate_metadata()
	_rebuild_command_list()
	_clear_inspector()
	_hide_errors()
	is_dirty = true


func _on_delete_cinematic() -> void:
	var selected: PackedInt32Array = cinematic_list.get_selected_items()
	if selected.is_empty():
		return

	var index: int = selected[0]
	if index < 0 or index >= cinematics.size():
		return

	var entry: Dictionary = cinematics[index]

	var confirm: ConfirmationDialog = ConfirmationDialog.new()
	confirm.title = "Delete Cinematic"
	confirm.dialog_text = "Delete '%s'?\n\nThis cannot be undone." % entry.name
	confirm.confirmed.connect(func() -> void:
		DirAccess.remove_absolute(entry.path)
		notify_resource_deleted(entry.name)
		_refresh_cinematic_list()
		current_cinematic_path = ""
		current_cinematic_data = {}
		_clear_inspector()
	)
	add_child(confirm)
	confirm.popup_centered()


func _on_save() -> void:
	if current_cinematic_path.is_empty():
		_show_errors(["No cinematic loaded"])
		return

	# Collect metadata
	var new_id: String = cinematic_id_edit.text.strip_edges()
	current_cinematic_data["cinematic_id"] = new_id
	current_cinematic_data["cinematic_name"] = cinematic_name_edit.text.strip_edges()
	current_cinematic_data["can_skip"] = can_skip_check.button_pressed
	current_cinematic_data["disable_player_input"] = disable_input_check.button_pressed

	# Validate
	var errors: Array[String] = _validate_cinematic()
	if errors.size() > 0:
		_show_errors(errors)
		return

	# Determine correct save path based on cinematic_id
	var dir_path: String = current_cinematic_path.get_base_dir()
	var expected_path: String = dir_path.path_join(new_id + ".json")
	var old_path: String = current_cinematic_path

	# If ID changed, we need to save to new path and delete old file
	if expected_path != current_cinematic_path:
		# Check if target file already exists (would be a conflict)
		if FileAccess.file_exists(expected_path):
			_show_errors(["Cannot rename: A cinematic with ID '%s' already exists" % new_id])
			return

	# Save to the correct path
	if save_json_file(expected_path, current_cinematic_data):
		# Delete old file if path changed
		if expected_path != old_path and FileAccess.file_exists(old_path):
			DirAccess.remove_absolute(old_path)

		current_cinematic_path = expected_path
		_hide_errors()
		is_dirty = false
		notify_resource_saved(new_id)

		# Refresh file list and filesystem
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().scan()
		_refresh_cinematic_list()


func _validate_cinematic() -> Array[String]:
	var errors: Array[String] = []

	if current_cinematic_data.get("cinematic_id", "").is_empty():
		errors.append("Cinematic ID is required")

	var commands: Array = current_cinematic_data.get("commands", [])
	for i: int in range(commands.size()):
		var cmd: Dictionary = commands[i]
		var cmd_type: String = cmd.get("type", "")

		if cmd_type.is_empty():
			errors.append("Command %d: Missing type" % (i + 1))
			continue

		if "params" not in cmd:
			errors.append("Command %d (%s): Missing params" % [i + 1, cmd_type])
			continue

		# Type-specific validation
		var params: Dictionary = cmd.get("params", {})
		match cmd_type:
			"dialog_line":
				if params.get("text", "").is_empty():
					errors.append("Command %d (dialog_line): Text is required" % (i + 1))
			"move_entity", "set_facing", "play_animation", "despawn_entity", "camera_follow":
				if cmd.get("target", "").is_empty():
					errors.append("Command %d (%s): Target actor_id is required" % [i + 1, cmd_type])
			"set_variable":
				if params.get("variable", "").is_empty():
					errors.append("Command %d (set_variable): Variable name is required" % (i + 1))

	return errors


# =============================================================================
# ID Auto-Generation Handlers
# =============================================================================

## Called when cinematic name changes - auto-generates ID if not locked
func _on_cinematic_name_changed(new_name: String) -> void:
	if _updating_ui:
		return
	if not _id_is_locked:
		cinematic_id_edit.text = SparklingEditorUtils.generate_id_from_name(new_name)


## Called when ID is manually edited
func _on_cinematic_id_manually_changed(_text: String) -> void:
	if _updating_ui:
		return
	# If user manually edits the ID field while it has focus, lock it
	if not _id_is_locked and cinematic_id_edit.has_focus():
		_id_is_locked = true
		_update_lock_button()


## Toggle the ID lock state
func _on_id_lock_toggled() -> void:
	_id_is_locked = not _id_is_locked
	_update_lock_button()
	# If unlocking, regenerate ID from current name
	if not _id_is_locked:
		cinematic_id_edit.text = SparklingEditorUtils.generate_id_from_name(cinematic_name_edit.text)


## Update the lock button appearance
func _update_lock_button() -> void:
	cinematic_id_lock_btn.text = "Lock" if _id_is_locked else "Unlock"
	cinematic_id_lock_btn.tooltip_text = "ID is locked. Click to unlock and auto-generate." if _id_is_locked else "ID auto-generates from name. Click to lock."


func _get_active_mod() -> String:
	var mod_id: String = SparklingEditorUtils.get_active_mod_id()
	if mod_id.is_empty():
		push_error("CinematicEditor: No active mod selected. Please select a mod from the dropdown.")
	return mod_id


## Refresh when tab becomes visible
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_characters()
		_refresh_cinematic_list()
