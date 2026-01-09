@tool
extends JsonEditorBase

## Visual Cinematic Editor
## Provides a visual interface for editing cinematic JSON files with:
## - Command list with drag-to-reorder
## - Type-specific command inspector
## - Validation before save
## - Character picker for dialog commands

const DialogLinePopupScript = preload("res://addons/sparkling_editor/ui/components/dialog_line_popup.gd")

# Widget context for the new widget system
var _widget_context: EditorWidgetContext

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
var target_field: OptionButton  # For commands with target (actor_id)

# UI Components - Metadata
var cinematic_id_edit: LineEdit
var cinematic_id_lock_btn: Button
var cinematic_name_edit: LineEdit
var description_edit: TextEdit
var can_skip_check: CheckBox
var disable_input_check: CheckBox
var save_button: Button

# UI Components - Actors panel
var actors_container: VBoxContainer
var actors_list: ItemList
var add_actor_button: Button
var delete_actor_button: Button
var selected_actor_index: int = -1

# Actor inspector fields
var actor_id_edit: LineEdit
var actor_entity_type_picker: OptionButton  # character, interactable, npc
var actor_entity_picker: OptionButton  # Entity ID based on selected type
var actor_pos_x_spin: SpinBox
var actor_pos_y_spin: SpinBox
var actor_facing_picker: OptionButton

# Legacy alias for backward compatibility
var actor_character_picker: OptionButton:
	get:
		return actor_entity_picker
	set(value):
		actor_entity_picker = value

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

# Character, NPC, Shop, Map, Battle, and Interactable caches for pickers
var _characters: Array[Resource] = []
var _npcs: Array[Resource] = []
var _shops: Array[Resource] = []
var _maps: Array[Resource] = []
var _interactables: Array[Resource] = []
var _battles: Array[Resource] = []


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


func _exit_tree() -> void:
	# Clean up EditorEventBus signal connections to prevent memory leaks
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	if event_bus:
		if event_bus.mods_reloaded.is_connected(_on_mods_reloaded):
			event_bus.mods_reloaded.disconnect(_on_mods_reloaded)
		if event_bus.resource_saved.is_connected(_on_resource_changed):
			event_bus.resource_saved.disconnect(_on_resource_changed)
		if event_bus.resource_created.is_connected(_on_resource_changed):
			event_bus.resource_created.disconnect(_on_resource_changed)


## Called when mods are reloaded via Refresh Mods button
func _on_mods_reloaded() -> void:
	_refresh_characters()
	_refresh_cinematic_list()


## Called when any resource is saved or created
func _on_resource_changed(resource_type: String, _resource_id: String, _resource: Resource) -> void:
	# Refresh characters/NPCs if either was modified
	if resource_type in ["character", "characters", "npc", "npcs"]:
		_refresh_characters()
	# Refresh maps and rebuild inspector to update map dropdowns
	elif resource_type == "map":
		_refresh_characters()  # This already refreshes _maps cache
		# Rebuild inspector if a command is selected (to refresh map dropdown)
		if selected_command_index >= 0:
			_build_inspector_for_command(selected_command_index)


func _refresh_characters() -> void:
	_characters.clear()
	_npcs.clear()
	_shops.clear()
	_maps.clear()
	_interactables.clear()
	_battles.clear()
	if ModLoader and ModLoader.registry:
		_characters = ModLoader.registry.get_all_resources("character")
		_npcs = ModLoader.registry.get_all_resources("npc")
		_shops = ModLoader.registry.get_all_resources("shop")
		_maps = ModLoader.registry.get_all_resources("map")
		_interactables = ModLoader.registry.get_all_resources("interactable")
		_battles = ModLoader.registry.get_all_resources("battle")

	# Update actor picker dropdown if it exists
	if actor_entity_picker:
		_populate_actor_entity_picker()

	# Invalidate widget context so it gets rebuilt
	_widget_context = null


## Build or refresh the widget context for the new widget system
## This context provides resource caches to widgets so they can populate dropdowns
func _build_widget_context() -> void:
	if not _widget_context:
		_widget_context = EditorWidgetContext.new()

	_widget_context.populate_from_editor_caches(
		_characters,
		_npcs_as_resources(),
		_shops_as_resources(),
		_battles_as_resources(),
		_maps_as_resources(),
		cinematics,
		_get_current_actor_ids()
	)


## Convert typed NPC array to untyped for context helper
func _npcs_as_resources() -> Array[Resource]:
	var result: Array[Resource] = []
	for npc: Resource in _npcs:
		result.append(npc)
	return result


## Convert typed shops array to untyped for context helper
func _shops_as_resources() -> Array[Resource]:
	var result: Array[Resource] = []
	for shop: Resource in _shops:
		result.append(shop)
	return result


## Convert typed battles array to untyped for context helper
func _battles_as_resources() -> Array[Resource]:
	var result: Array[Resource] = []
	for battle: Resource in _battles:
		result.append(battle)
	return result


## Convert typed maps array to untyped for context helper
func _maps_as_resources() -> Array[Resource]:
	var result: Array[Resource] = []
	for map_res: Resource in _maps:
		result.append(map_res)
	return result


func _setup_ui() -> void:
	# Root Control uses layout_mode = 1 with anchors in .tscn for proper TabContainer containment
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
	title.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
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

	# Actors section (collapsible)
	_setup_actors_section(center_panel)

	# Command list header
	var cmd_header: HBoxContainer = HBoxContainer.new()
	cmd_header.add_theme_constant_override("separation", 4)
	center_panel.add_child(cmd_header)

	var cmd_label: Label = Label.new()
	cmd_label.text = "Commands"
	cmd_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
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


func _setup_actors_section(parent: VBoxContainer) -> void:
	# Collapsible actors section
	actors_container = VBoxContainer.new()
	actors_container.add_theme_constant_override("separation", 4)
	parent.add_child(actors_container)

	# Header with toggle
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	actors_container.add_child(header)

	var actors_label: Label = Label.new()
	actors_label.text = "Actors"
	actors_label.add_theme_font_size_override("font_size", 14)
	actors_label.tooltip_text = "Actors spawn before commands execute. Use for characters that need to exist at cinematic start."
	header.add_child(actors_label)

	header.add_spacer(false)

	add_actor_button = Button.new()
	add_actor_button.text = "+ Add"
	add_actor_button.tooltip_text = "Add a new actor"
	add_actor_button.pressed.connect(_on_add_actor)
	header.add_child(add_actor_button)

	delete_actor_button = Button.new()
	delete_actor_button.text = "Del"
	delete_actor_button.tooltip_text = "Delete selected actor"
	delete_actor_button.disabled = true
	delete_actor_button.pressed.connect(_on_delete_actor)
	header.add_child(delete_actor_button)

	# Actor list (compact)
	actors_list = ItemList.new()
	actors_list.custom_minimum_size.y = 60
	actors_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	actors_list.item_selected.connect(_on_actor_selected)
	actors_list.allow_reselect = true
	actors_container.add_child(actors_list)

	# Actor inline editor (shown when actor is selected)
	var actor_editor: VBoxContainer = VBoxContainer.new()
	actor_editor.name = "ActorEditor"
	actor_editor.add_theme_constant_override("separation", 4)
	actors_container.add_child(actor_editor)

	# Actor ID row
	var id_row: HBoxContainer = HBoxContainer.new()
	actor_editor.add_child(id_row)

	var id_label: Label = Label.new()
	id_label.text = "ID:"
	id_label.custom_minimum_size.x = 70
	id_row.add_child(id_label)

	actor_id_edit = LineEdit.new()
	actor_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actor_id_edit.placeholder_text = "unique_actor_id"
	actor_id_edit.tooltip_text = "Unique ID to reference this actor in commands"
	actor_id_edit.text_changed.connect(_on_actor_id_changed)
	id_row.add_child(actor_id_edit)

	# Entity type picker row
	var type_row: HBoxContainer = HBoxContainer.new()
	actor_editor.add_child(type_row)

	var type_label: Label = Label.new()
	type_label.text = "Type:"
	type_label.custom_minimum_size.x = 70
	type_row.add_child(type_label)

	actor_entity_type_picker = OptionButton.new()
	actor_entity_type_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actor_entity_type_picker.tooltip_text = "Type of entity to spawn"
	actor_entity_type_picker.add_item("Character", 0)
	actor_entity_type_picker.add_item("Interactable", 1)
	actor_entity_type_picker.add_item("NPC", 2)
	actor_entity_type_picker.set_item_metadata(0, "character")
	actor_entity_type_picker.set_item_metadata(1, "interactable")
	actor_entity_type_picker.set_item_metadata(2, "npc")
	actor_entity_type_picker.item_selected.connect(_on_actor_entity_type_changed)
	type_row.add_child(actor_entity_type_picker)

	# Entity picker row (changes based on type)
	var entity_row: HBoxContainer = HBoxContainer.new()
	actor_editor.add_child(entity_row)

	var entity_label: Label = Label.new()
	entity_label.text = "Entity:"
	entity_label.custom_minimum_size.x = 70
	entity_row.add_child(entity_label)

	actor_entity_picker = OptionButton.new()
	actor_entity_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actor_entity_picker.tooltip_text = "Entity to spawn (provides sprite)"
	actor_entity_picker.item_selected.connect(_on_actor_entity_changed)
	entity_row.add_child(actor_entity_picker)

	# Position row
	var pos_row: HBoxContainer = HBoxContainer.new()
	actor_editor.add_child(pos_row)

	var pos_label: Label = Label.new()
	pos_label.text = "Position:"
	pos_label.custom_minimum_size.x = 70
	pos_row.add_child(pos_label)

	var x_label: Label = Label.new()
	x_label.text = "X:"
	pos_row.add_child(x_label)

	actor_pos_x_spin = SpinBox.new()
	actor_pos_x_spin.min_value = -1000
	actor_pos_x_spin.max_value = 1000
	actor_pos_x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actor_pos_x_spin.tooltip_text = "Grid X coordinate"
	actor_pos_x_spin.value_changed.connect(_on_actor_position_changed)
	pos_row.add_child(actor_pos_x_spin)

	var y_label: Label = Label.new()
	y_label.text = "Y:"
	pos_row.add_child(y_label)

	actor_pos_y_spin = SpinBox.new()
	actor_pos_y_spin.min_value = -1000
	actor_pos_y_spin.max_value = 1000
	actor_pos_y_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actor_pos_y_spin.tooltip_text = "Grid Y coordinate"
	actor_pos_y_spin.value_changed.connect(_on_actor_position_changed)
	pos_row.add_child(actor_pos_y_spin)

	# Facing row
	var facing_row: HBoxContainer = HBoxContainer.new()
	actor_editor.add_child(facing_row)

	var facing_label: Label = Label.new()
	facing_label.text = "Facing:"
	facing_label.custom_minimum_size.x = 70
	facing_row.add_child(facing_label)

	actor_facing_picker = OptionButton.new()
	actor_facing_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actor_facing_picker.add_item("down", 0)
	actor_facing_picker.add_item("up", 1)
	actor_facing_picker.add_item("left", 2)
	actor_facing_picker.add_item("right", 3)
	actor_facing_picker.tooltip_text = "Initial facing direction"
	actor_facing_picker.item_selected.connect(_on_actor_facing_changed)
	facing_row.add_child(actor_facing_picker)

	# Separator
	var sep: HSeparator = HSeparator.new()
	actors_container.add_child(sep)

	# Initially hide editor until actor is selected
	actor_editor.visible = false


func _setup_inspector_panel(parent: HSplitContainer) -> void:
	var right_panel: VBoxContainer = VBoxContainer.new()
	right_panel.custom_minimum_size.x = 320
	right_panel.add_theme_constant_override("separation", 4)
	parent.add_child(right_panel)

	# Header
	var header: Label = Label.new()
	header.text = "Command Inspector"
	header.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
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

	# Clean up old submenus
	for child: Node in popup.get_children():
		child.queue_free()

	# Get merged definitions (hardcoded + dynamic from executors)
	var definitions: Dictionary = CinematicCommandDefs.get_merged_definitions()

	# Build categories dynamically from definitions
	var categories: Dictionary = CinematicCommandDefs.build_categories(definitions)

	# Create submenus for each category
	for category: String in categories.keys():
		var submenu: PopupMenu = PopupMenu.new()
		submenu.name = category + "_submenu"

		var idx: int = 0
		for cmd_type: String in categories[category]:
			if cmd_type in definitions:
				var def: Dictionary = definitions[cmd_type]
				var desc: String = def.get("description", cmd_type)
				submenu.add_item(cmd_type + " - " + desc.substr(0, 35), idx)
				submenu.set_item_metadata(idx, cmd_type)
				idx += 1

		submenu.id_pressed.connect(_on_submenu_command_selected.bind(submenu))
		popup.add_child(submenu)
		popup.add_submenu_item(category, submenu.name)


func _on_submenu_command_selected(id: int, submenu: PopupMenu) -> void:
	var cmd_type: String = submenu.get_item_metadata(id)
	if not cmd_type.is_empty():
		_add_new_command(cmd_type)


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
	var definitions: Dictionary = CinematicCommandDefs.get_merged_definitions()

	if cmd_type in definitions:
		var def: Dictionary = definitions[cmd_type]
		if "has_target" in def and def.get("has_target", false):
			new_cmd["target"] = ""
		if "params" in def:
			var def_params: Dictionary = def.get("params", {})
			for param_name: String in def_params.keys():
				var param_def: Dictionary = def_params[param_name]
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
	selected_actor_index = -1
	is_dirty = false

	_populate_metadata()
	_rebuild_actors_list()
	_rebuild_command_list()
	_clear_inspector()
	_clear_actor_editor()
	_hide_errors()


## Clear actor editor when loading new cinematic
func _clear_actor_editor() -> void:
	var actor_editor: VBoxContainer = _get_actor_editor()
	if actor_editor:
		actor_editor.visible = false
	delete_actor_button.disabled = true


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
		"set_position":
			var pos: Array = params.get("position", [0, 0])
			summary = "%s -> (%s, %s)" % [target, pos[0] if pos.size() > 0 else 0, pos[1] if pos.size() > 1 else 0]
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
	type_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	type_label.add_theme_color_override("font_color", _get_command_color(cmd_type))
	inspector_panel.add_child(type_label)

	# Description (from merged definitions)
	var definitions: Dictionary = CinematicCommandDefs.get_merged_definitions()
	if cmd_type in definitions and "description" in definitions[cmd_type]:
		var cmd_def: Dictionary = definitions[cmd_type]
		var desc_label: Label = Label.new()
		desc_label.text = cmd_def.get("description", "")
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
		target_label.text = "Target (Actor):"
		target_label.custom_minimum_size.x = 130
		target_row.add_child(target_label)

		target_field = OptionButton.new()
		target_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		target_field.add_item("(None)", 0)
		target_field.set_item_metadata(0, "")
		var current_target: String = cmd.get("target", "")
		var selected_idx: int = 0
		var item_idx: int = 1
		for actor_id: String in _get_current_actor_ids():
			target_field.add_item(actor_id, item_idx)
			target_field.set_item_metadata(item_idx, actor_id)
			if actor_id == current_target:
				selected_idx = item_idx
			item_idx += 1
		target_field.select(selected_idx)
		target_field.item_selected.connect(_on_target_selected)
		target_row.add_child(target_field)

	# Build parameter fields based on definition (using merged definitions)
	if cmd_type in definitions and "params" in definitions[cmd_type]:
		var def: Dictionary = definitions[cmd_type]
		var def_params: Dictionary = def.get("params", {})
		for param_name: String in def_params.keys():
			var param_def: Dictionary = def_params[param_name]
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
	var param_type: String = param_def.get("type", "string")

	# Ensure context is ready
	_build_widget_context()

	# Try widget factory first
	var widget: EditorWidgetBase = ParamWidgetFactory.create_widget(param_type, param_def, _widget_context)

	if widget:
		# Special handling for command_array - set param name for accent color
		if widget is CommandArrayWidget:
			var cmd_widget: CommandArrayWidget = widget as CommandArrayWidget
			cmd_widget.set_param_name(param_name)

		# Command array gets full width, no label row
		if param_type == "command_array":
			widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			widget.set_value(current_value)
			widget.value_changed.connect(_on_widget_value_changed.bind(param_name))
			inspector_panel.add_child(widget)
			inspector_fields[param_name] = widget
			return

		# Create row with label for other widget types
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		inspector_panel.add_child(row)

		var label: Label = Label.new()
		label.text = param_name.replace("_", " ").capitalize() + ":"
		label.custom_minimum_size.x = 130
		label.tooltip_text = param_def.get("hint", "")
		row.add_child(label)

		# Set value and connect signal
		widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		widget.set_value(current_value)
		widget.value_changed.connect(_on_widget_value_changed.bind(param_name))
		row.add_child(widget)

		inspector_fields[param_name] = widget
		return

	# Fallback for unsupported types (path, variant, color, or unknown)
	_create_fallback_param_field(param_name, param_def, current_value)


## Handle value changes from the new widget system
func _on_widget_value_changed(new_value: Variant, param_name: String) -> void:
	if _updating_ui or selected_command_index < 0:
		return
	var commands: Array = current_cinematic_data.get("commands", [])
	if selected_command_index >= commands.size():
		return
	var cmd: Dictionary = commands[selected_command_index]
	if "params" not in cmd:
		cmd["params"] = {}
	cmd["params"][param_name] = new_value
	is_dirty = true
	_rebuild_command_list()  # Update summary in list
	command_list.select(selected_command_index)


## Fallback for param types not yet supported by the widget system
func _create_fallback_param_field(param_name: String, param_def: Dictionary, current_value: Variant) -> void:
	var param_type: String = param_def.get("type", "string")

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	inspector_panel.add_child(row)

	var label: Label = Label.new()
	label.text = param_name.replace("_", " ").capitalize() + ":"
	label.custom_minimum_size.x = 130
	label.tooltip_text = param_def.get("hint", "")
	row.add_child(label)

	var control: Control

	match param_type:
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

		_:  # Unknown types - JSON fallback
			var json_edit: TextEdit = TextEdit.new()
			json_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			json_edit.custom_minimum_size.y = 60
			json_edit.text = JSON.stringify(current_value, "  ") if current_value != null else ""
			json_edit.text_changed.connect(func() -> void:
				var parsed: Variant = JSON.parse_string(json_edit.text)
				if parsed != null:
					_on_widget_value_changed(parsed, param_name)
			)
			control = json_edit

	row.add_child(control)
	inspector_fields[param_name] = control


# Parameter change handlers
func _on_target_selected(item_index: int) -> void:
	if _updating_ui or selected_command_index < 0:
		return
	var commands: Array = current_cinematic_data.get("commands", [])
	var actor_id: String = target_field.get_item_metadata(item_index)
	commands[selected_command_index]["target"] = actor_id
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


# Legacy handlers for fallback param types (color, path, variant)
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
	var original_cmd: Dictionary = commands[selected_command_index]
	var cmd: Dictionary = original_cmd.duplicate(true)
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
		"actors": [],
		"commands": []
	}

	current_cinematic_path = new_path
	selected_actor_index = -1
	_populate_metadata()
	_rebuild_actors_list()
	_rebuild_command_list()
	_clear_inspector()
	_clear_actor_editor()
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


# =============================================================================
# ACTORS SECTION HANDLERS
# =============================================================================

## Rebuild the actors list from current data
func _rebuild_actors_list() -> void:
	actors_list.clear()
	var actors: Array = current_cinematic_data.get("actors", [])

	for i: int in range(actors.size()):
		var actor: Dictionary = actors[i]
		var actor_id: String = actor.get("actor_id", "unnamed")

		# Get entity info (with backward compatibility for character_id)
		var entity_type: String = actor.get("entity_type", "")
		var entity_id: String = actor.get("entity_id", "")
		if entity_type.is_empty() and entity_id.is_empty():
			entity_id = actor.get("character_id", "")
			if not entity_id.is_empty():
				entity_type = "character"

		var display: String = actor_id
		if not entity_id.is_empty():
			var type_abbrev: String = ""
			match entity_type:
				"character": type_abbrev = "char"
				"interactable": type_abbrev = "obj"
				"npc": type_abbrev = "npc"
				_: type_abbrev = entity_type
			display += " [%s: %s]" % [type_abbrev, entity_id]
		actors_list.add_item(display)

	# Update button states
	delete_actor_button.disabled = selected_actor_index < 0


## Populate the actor entity picker dropdown based on selected entity type
func _populate_actor_entity_picker() -> void:
	actor_entity_picker.clear()
	actor_entity_picker.add_item("(None)", 0)
	actor_entity_picker.set_item_metadata(0, "")

	var entity_type: String = "character"
	if actor_entity_type_picker and actor_entity_type_picker.selected >= 0:
		entity_type = actor_entity_type_picker.get_item_metadata(actor_entity_type_picker.selected)

	var idx: int = 1
	match entity_type:
		"character":
			for char_res: Resource in _characters:
				if char_res:
					var display_name: String = SparklingEditorUtils.get_resource_display_name_with_mod(char_res, "character_name")
					var char_id: String = ""
					if char_res.resource_path:
						char_id = char_res.resource_path.get_file().get_basename()
					actor_entity_picker.add_item(display_name, idx)
					actor_entity_picker.set_item_metadata(idx, char_id)
					idx += 1
		"interactable":
			for inter_res: Resource in _interactables:
				if inter_res:
					var display_name: String = SparklingEditorUtils.get_resource_display_name_with_mod(inter_res, "display_name")
					var inter_id: String = ""
					if inter_res.resource_path:
						inter_id = inter_res.resource_path.get_file().get_basename()
					actor_entity_picker.add_item(display_name, idx)
					actor_entity_picker.set_item_metadata(idx, inter_id)
					idx += 1
		"npc":
			for npc_res: Resource in _npcs:
				if npc_res:
					var display_name: String = SparklingEditorUtils.get_resource_display_name_with_mod(npc_res, "npc_name")
					var npc_id: String = ""
					if npc_res.resource_path:
						npc_id = npc_res.resource_path.get_file().get_basename()
					actor_entity_picker.add_item(display_name, idx)
					actor_entity_picker.set_item_metadata(idx, npc_id)
					idx += 1


## Get actor editor container
func _get_actor_editor() -> VBoxContainer:
	return actors_container.get_node_or_null("ActorEditor") as VBoxContainer


## Add a new actor
func _on_add_actor() -> void:
	if "actors" not in current_cinematic_data:
		current_cinematic_data["actors"] = []

	var actors: Array = current_cinematic_data["actors"]

	# Generate unique actor ID
	var base_id: String = "actor"
	var counter: int = 1
	var new_id: String = base_id + "_" + str(counter)
	while _actor_id_exists(new_id, actors):
		counter += 1
		new_id = base_id + "_" + str(counter)

	var new_actor: Dictionary = {
		"actor_id": new_id,
		"entity_type": "character",
		"entity_id": "",
		"position": [0, 0],
		"facing": "down"
	}

	actors.append(new_actor)
	_rebuild_actors_list()

	# Select the new actor
	selected_actor_index = actors.size() - 1
	actors_list.select(selected_actor_index)
	_on_actor_selected(selected_actor_index)

	is_dirty = true


## Get all actor IDs from the current cinematic
func _get_current_actor_ids() -> Array[String]:
	var result: Array[String] = []
	if not current_cinematic_data:
		return result
	var actors: Array = current_cinematic_data.get("actors", [])
	for actor_item: Variant in actors:
		if actor_item is Dictionary:
			var actor_dict: Dictionary = actor_item
			var actor_id: String = actor_dict.get("actor_id", "")
			if not actor_id.is_empty():
				result.append(actor_id)
	return result


## Check if an actor ID already exists
func _actor_id_exists(actor_id: String, actors: Array) -> bool:
	for actor_item: Variant in actors:
		if actor_item is Dictionary:
			var actor_dict: Dictionary = actor_item
			if actor_dict.get("actor_id", "") == actor_id:
				return true
	return false


## Delete the selected actor
func _on_delete_actor() -> void:
	if selected_actor_index < 0:
		return

	var actors: Array = current_cinematic_data.get("actors", [])
	if selected_actor_index >= actors.size():
		return

	actors.remove_at(selected_actor_index)

	# Clear selection and hide editor
	selected_actor_index = -1
	var actor_editor: VBoxContainer = _get_actor_editor()
	if actor_editor:
		actor_editor.visible = false

	_rebuild_actors_list()
	is_dirty = true


## Handle actor selection
func _on_actor_selected(index: int) -> void:
	selected_actor_index = index
	delete_actor_button.disabled = false

	var actors: Array = current_cinematic_data.get("actors", [])
	if index < 0 or index >= actors.size():
		var actor_editor: VBoxContainer = _get_actor_editor()
		if actor_editor:
			actor_editor.visible = false
		return

	var actor: Dictionary = actors[index]

	# Show and populate editor
	var actor_editor: VBoxContainer = _get_actor_editor()
	if actor_editor:
		actor_editor.visible = true

	_updating_ui = true

	# Set actor ID
	actor_id_edit.text = actor.get("actor_id", "")

	# Determine entity type (with backward compatibility for character_id)
	var entity_type: String = actor.get("entity_type", "")
	var entity_id: String = actor.get("entity_id", "")

	# Backward compatibility: character_id -> entity_type="character"
	if entity_type.is_empty() and entity_id.is_empty():
		var character_id: String = actor.get("character_id", "")
		if not character_id.is_empty():
			entity_type = "character"
			entity_id = character_id

	if entity_type.is_empty():
		entity_type = "character"

	# Set entity type picker
	var type_idx: int = 0
	match entity_type:
		"character": type_idx = 0
		"interactable": type_idx = 1
		"npc": type_idx = 2
	actor_entity_type_picker.select(type_idx)

	# Populate entity picker for this type
	_populate_actor_entity_picker()

	# Set entity
	var entity_idx: int = 0
	for i: int in range(actor_entity_picker.item_count):
		if actor_entity_picker.get_item_metadata(i) == entity_id:
			entity_idx = i
			break
	actor_entity_picker.select(entity_idx)

	# Set position
	var pos: Variant = actor.get("position", [0, 0])
	if pos is Array:
		var pos_arr: Array = pos
		if pos_arr.size() >= 2:
			actor_pos_x_spin.value = pos_arr[0]
			actor_pos_y_spin.value = pos_arr[1]
		else:
			actor_pos_x_spin.value = 0
			actor_pos_y_spin.value = 0
	else:
		actor_pos_x_spin.value = 0
		actor_pos_y_spin.value = 0

	# Set facing
	var facing: String = actor.get("facing", "down")
	var facing_idx: int = 0
	match facing:
		"down": facing_idx = 0
		"up": facing_idx = 1
		"left": facing_idx = 2
		"right": facing_idx = 3
	actor_facing_picker.select(facing_idx)

	_updating_ui = false


## Handle actor ID change
func _on_actor_id_changed(new_id: String) -> void:
	if _updating_ui or selected_actor_index < 0:
		return

	var actors: Array = current_cinematic_data.get("actors", [])
	if selected_actor_index >= actors.size():
		return

	actors[selected_actor_index]["actor_id"] = new_id
	_rebuild_actors_list()
	actors_list.select(selected_actor_index)
	is_dirty = true


## Handle actor entity type change
func _on_actor_entity_type_changed(index: int) -> void:
	if _updating_ui or selected_actor_index < 0:
		return

	var actors: Array = current_cinematic_data.get("actors", [])
	if selected_actor_index >= actors.size():
		return

	var entity_type: String = actor_entity_type_picker.get_item_metadata(index)
	var selected_actor: Dictionary = actors[selected_actor_index]
	selected_actor["entity_type"] = entity_type
	# Clear entity_id when type changes
	selected_actor["entity_id"] = ""
	# Remove legacy character_id if present
	selected_actor.erase("character_id")

	# Repopulate entity picker for new type
	_populate_actor_entity_picker()
	actor_entity_picker.select(0)  # Select "(None)"

	_rebuild_actors_list()
	actors_list.select(selected_actor_index)
	is_dirty = true


## Handle actor entity change
func _on_actor_entity_changed(index: int) -> void:
	if _updating_ui or selected_actor_index < 0:
		return

	var actors: Array = current_cinematic_data.get("actors", [])
	if selected_actor_index >= actors.size():
		return

	var entity_id: Variant = actor_entity_picker.get_item_metadata(index)
	var entity_type: String = actor_entity_type_picker.get_item_metadata(actor_entity_type_picker.selected)

	var selected_actor: Dictionary = actors[selected_actor_index]
	selected_actor["entity_type"] = entity_type
	selected_actor["entity_id"] = entity_id if entity_id else ""
	# Remove legacy character_id if present
	selected_actor.erase("character_id")

	_rebuild_actors_list()
	actors_list.select(selected_actor_index)
	is_dirty = true


## Handle actor position change
func _on_actor_position_changed(_value: float) -> void:
	if _updating_ui or selected_actor_index < 0:
		return

	var actors: Array = current_cinematic_data.get("actors", [])
	if selected_actor_index >= actors.size():
		return

	actors[selected_actor_index]["position"] = [int(actor_pos_x_spin.value), int(actor_pos_y_spin.value)]
	is_dirty = true


## Handle actor facing change
func _on_actor_facing_changed(index: int) -> void:
	if _updating_ui or selected_actor_index < 0:
		return

	var actors: Array = current_cinematic_data.get("actors", [])
	if selected_actor_index >= actors.size():
		return

	var facing: String = "down"
	match index:
		0: facing = "down"
		1: facing = "up"
		2: facing = "left"
		3: facing = "right"

	actors[selected_actor_index]["facing"] = facing
	is_dirty = true


## Convert Variant to float with type safety
func _variant_to_float(value: Variant, default: float = 0.0) -> float:
	if value is float:
		return value
	if value is int:
		var int_val: int = value
		return float(int_val)
	return default


## Convert Variant to bool with type safety
func _variant_to_bool(value: Variant, default: bool = false) -> bool:
	if value is bool:
		return value
	return default


# =============================================================================
# CHOICES EDITOR SECTION (for show_choice command)
# =============================================================================

## Available actions for show_choice command
const CHOICE_ACTIONS: Array[String] = ["none", "battle", "set_flag", "cinematic", "set_variable", "shop"]

## Create a UI row for editing a single choice
func _create_choice_row(index: int, choice_data: Dictionary, param_name: String, container: VBoxContainer) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_meta("choice_index", index)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# Header row with choice number and delete button
	var header: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header)

	var num_label: Label = Label.new()
	num_label.text = "Choice %d" % (index + 1)
	num_label.add_theme_font_size_override("font_size", 12)
	header.add_child(num_label)

	header.add_spacer(false)

	var del_btn: Button = Button.new()
	del_btn.text = "X"
	del_btn.tooltip_text = "Remove this choice"
	del_btn.custom_minimum_size.x = 24
	del_btn.pressed.connect(_on_remove_choice.bind(index, param_name, container))
	header.add_child(del_btn)

	# Label field
	var label_row: HBoxContainer = HBoxContainer.new()
	vbox.add_child(label_row)

	var label_lbl: Label = Label.new()
	label_lbl.text = "Label:"
	label_lbl.custom_minimum_size.x = 50
	label_row.add_child(label_lbl)

	var label_edit: LineEdit = LineEdit.new()
	label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_edit.text = choice_data.get("label", "")
	label_edit.placeholder_text = "Choice text shown to player"
	label_edit.text_changed.connect(_on_choice_field_changed.bind(index, "label", param_name))
	label_row.add_child(label_edit)

	# Action row
	var action_row: HBoxContainer = HBoxContainer.new()
	vbox.add_child(action_row)

	var action_lbl: Label = Label.new()
	action_lbl.text = "Action:"
	action_lbl.custom_minimum_size.x = 50
	action_row.add_child(action_lbl)

	var action_picker: OptionButton = OptionButton.new()
	action_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current_action: String = choice_data.get("action", "none")
	for i: int in range(CHOICE_ACTIONS.size()):
		action_picker.add_item(CHOICE_ACTIONS[i])
		if CHOICE_ACTIONS[i] == current_action:
			action_picker.select(i)
	action_picker.item_selected.connect(_on_choice_action_changed.bind(index, param_name))
	action_row.add_child(action_picker)

	# Value field - use picker for battle/shop/cinematic, text for others
	var value_row: HBoxContainer = HBoxContainer.new()
	value_row.name = "ValueRow"
	vbox.add_child(value_row)

	var value_lbl: Label = Label.new()
	value_lbl.text = "Value:"
	value_lbl.custom_minimum_size.x = 50
	value_row.add_child(value_lbl)

	var current_value: String = choice_data.get("value", "")
	var value_control: Control = _create_choice_value_control(current_action, current_value, index, param_name)
	value_row.add_child(value_control)

	# Battle-specific options (only shown when action is "battle")
	if current_action == "battle":
		_add_battle_options_to_choice(vbox, choice_data, index, param_name)

	return panel


## Get hint text for value field based on action type
func _get_value_hint(action: String) -> String:
	match action:
		"battle": return "battle_id"
		"set_flag": return "flag_name"
		"cinematic": return "cinematic_id"
		"set_variable": return "key:value"
		"shop": return "shop_id"
		"none": return "(not used)"
		_: return ""


## Add battle-specific options to a choice panel (on_victory_cinematic, etc.)
func _add_battle_options_to_choice(container: VBoxContainer, choice_data: Dictionary, choice_index: int, param_name: String) -> void:
	# Separator
	var sep: HSeparator = HSeparator.new()
	container.add_child(sep)

	# Header for battle options
	var header: Label = Label.new()
	header.text = "Battle Outcome Options"
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container.add_child(header)

	# On Victory Cinematic
	var victory_cin_row: HBoxContainer = HBoxContainer.new()
	container.add_child(victory_cin_row)
	var victory_cin_lbl: Label = Label.new()
	victory_cin_lbl.text = "On Victory:"
	victory_cin_lbl.custom_minimum_size.x = 70
	victory_cin_row.add_child(victory_cin_lbl)
	var victory_cin_picker: OptionButton = _create_cinematic_picker_for_battle_choice(
		choice_data.get("on_victory_cinematic", ""),
		choice_index,
		param_name,
		"on_victory_cinematic"
	)
	victory_cin_row.add_child(victory_cin_picker)

	# On Defeat Cinematic
	var defeat_cin_row: HBoxContainer = HBoxContainer.new()
	container.add_child(defeat_cin_row)
	var defeat_cin_lbl: Label = Label.new()
	defeat_cin_lbl.text = "On Defeat:"
	defeat_cin_lbl.custom_minimum_size.x = 70
	defeat_cin_row.add_child(defeat_cin_lbl)
	var defeat_cin_picker: OptionButton = _create_cinematic_picker_for_battle_choice(
		choice_data.get("on_defeat_cinematic", ""),
		choice_index,
		param_name,
		"on_defeat_cinematic"
	)
	defeat_cin_row.add_child(defeat_cin_picker)

	# On Victory Flags
	var victory_flags_row: HBoxContainer = HBoxContainer.new()
	container.add_child(victory_flags_row)
	var victory_flags_lbl: Label = Label.new()
	victory_flags_lbl.text = "Victory Flags:"
	victory_flags_lbl.custom_minimum_size.x = 70
	victory_flags_row.add_child(victory_flags_lbl)
	var victory_flags_edit: LineEdit = LineEdit.new()
	victory_flags_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	victory_flags_edit.placeholder_text = "flag1, flag2, ..."
	var victory_flags: Variant = choice_data.get("on_victory_flags", [])
	if victory_flags is Array:
		victory_flags_edit.text = ", ".join(victory_flags)
	victory_flags_edit.text_changed.connect(_on_choice_battle_flags_changed.bind(choice_index, param_name, "on_victory_flags"))
	victory_flags_row.add_child(victory_flags_edit)

	# On Defeat Flags
	var defeat_flags_row: HBoxContainer = HBoxContainer.new()
	container.add_child(defeat_flags_row)
	var defeat_flags_lbl: Label = Label.new()
	defeat_flags_lbl.text = "Defeat Flags:"
	defeat_flags_lbl.custom_minimum_size.x = 70
	defeat_flags_row.add_child(defeat_flags_lbl)
	var defeat_flags_edit: LineEdit = LineEdit.new()
	defeat_flags_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defeat_flags_edit.placeholder_text = "flag1, flag2, ..."
	var defeat_flags: Variant = choice_data.get("on_defeat_flags", [])
	if defeat_flags is Array:
		defeat_flags_edit.text = ", ".join(defeat_flags)
	defeat_flags_edit.text_changed.connect(_on_choice_battle_flags_changed.bind(choice_index, param_name, "on_defeat_flags"))
	defeat_flags_row.add_child(defeat_flags_edit)


## Create cinematic picker for battle choice outcome
func _create_cinematic_picker_for_battle_choice(current_value: String, choice_index: int, param_name: String, field_name: String) -> OptionButton:
	var picker: OptionButton = OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_item("(None)", 0)
	picker.set_item_metadata(0, "")

	var selected_idx: int = 0
	var item_idx: int = 1

	# Use the cinematics list (same as _create_cinematic_picker)
	for entry: Dictionary in cinematics:
		var cinematic_id: String = entry.get("name", "")
		var mod_id: String = entry.get("mod_id", "")

		var display_name: String = "[%s] %s" % [mod_id, cinematic_id] if not mod_id.is_empty() else cinematic_id
		picker.add_item(display_name, item_idx)
		picker.set_item_metadata(item_idx, cinematic_id)

		if cinematic_id == current_value:
			selected_idx = item_idx
		item_idx += 1

	picker.select(selected_idx)
	picker.item_selected.connect(_on_choice_battle_cinematic_changed.bind(choice_index, param_name, field_name, picker))
	return picker


## Handle cinematic picker change for battle choice
func _on_choice_battle_cinematic_changed(item_index: int, choice_index: int, param_name: String, field_name: String, picker: OptionButton) -> void:
	if _updating_ui or selected_command_index < 0:
		return

	var cin_id: String = picker.get_item_metadata(item_index) if item_index >= 0 else ""

	var commands: Array = current_cinematic_data.get("commands", [])
	var params: Dictionary = commands[selected_command_index].get("params", {})

	if param_name in params and params[param_name] is Array:
		var choices: Array = params[param_name]
		if choice_index >= 0 and choice_index < choices.size():
			var choice: Variant = choices[choice_index]
			if choice is Dictionary:
				choice[field_name] = cin_id
				is_dirty = true


## Handle flags text change for battle choice
func _on_choice_battle_flags_changed(new_text: String, choice_index: int, param_name: String, field_name: String) -> void:
	if _updating_ui or selected_command_index < 0:
		return

	# Parse comma-separated flags
	var flags: Array = []
	for flag: String in new_text.split(","):
		var trimmed: String = flag.strip_edges()
		if not trimmed.is_empty():
			flags.append(trimmed)

	var commands: Array = current_cinematic_data.get("commands", [])
	var params: Dictionary = commands[selected_command_index].get("params", {})

	if param_name in params and params[param_name] is Array:
		var choices: Array = params[param_name]
		if choice_index >= 0 and choice_index < choices.size():
			var choice: Variant = choices[choice_index]
			if choice is Dictionary:
				choice[field_name] = flags
				is_dirty = true


## Create the appropriate value control based on action type
func _create_choice_value_control(action: String, current_value: String, choice_index: int, param_name: String) -> Control:
	match action:
		"battle":
			return _create_battle_picker(current_value, choice_index, param_name)
		"shop":
			return _create_shop_picker_for_choice(current_value, choice_index, param_name)
		"cinematic":
			return _create_cinematic_picker(current_value, choice_index, param_name)
		_:
			# Default to LineEdit for set_flag, set_variable, none, etc.
			var line_edit: LineEdit = LineEdit.new()
			line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line_edit.text = current_value
			line_edit.placeholder_text = _get_value_hint(action)
			line_edit.text_changed.connect(_on_choice_field_changed.bind(choice_index, "value", param_name))
			return line_edit


## Create battle picker dropdown for choice value
func _create_battle_picker(current_value: String, choice_index: int, param_name: String) -> OptionButton:
	var picker: OptionButton = OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_item("(Select battle)", 0)
	picker.set_item_metadata(0, "")

	var selected_idx: int = 0
	var item_idx: int = 1

	for battle_res: Resource in _battles:
		if battle_res:
			var battle_id: String = ""
			var battle_name: String = ""

			if "battle_id" in battle_res:
				battle_id = str(battle_res.get("battle_id"))
			if "battle_name" in battle_res:
				battle_name = str(battle_res.get("battle_name"))

			if battle_id.is_empty():
				battle_id = battle_res.resource_path.get_file().get_basename()
			if battle_name.is_empty():
				battle_name = battle_id

			# Get source mod
			var mod_id: String = ""
			if ModLoader and ModLoader.registry:
				var resource_id: String = battle_res.resource_path.get_file().get_basename()
				mod_id = ModLoader.registry.get_resource_source(resource_id)

			var display_name: String = "[%s] %s" % [mod_id, battle_name] if not mod_id.is_empty() else battle_name
			picker.add_item(display_name, item_idx)
			picker.set_item_metadata(item_idx, battle_id)

			if battle_id == current_value:
				selected_idx = item_idx
			item_idx += 1

	picker.select(selected_idx)
	picker.item_selected.connect(_on_choice_value_picker_changed.bind(choice_index, param_name, picker))
	return picker


## Create shop picker dropdown for choice value
func _create_shop_picker_for_choice(current_value: String, choice_index: int, param_name: String) -> OptionButton:
	var picker: OptionButton = OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_item("(Select shop)", 0)
	picker.set_item_metadata(0, "")

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
			picker.add_item(display_name, item_idx)
			picker.set_item_metadata(item_idx, shop_id)

			if shop_id == current_value:
				selected_idx = item_idx
			item_idx += 1

	picker.select(selected_idx)
	picker.item_selected.connect(_on_choice_value_picker_changed.bind(choice_index, param_name, picker))
	return picker


## Create cinematic picker dropdown for choice value
func _create_cinematic_picker(current_value: String, choice_index: int, param_name: String) -> OptionButton:
	var picker: OptionButton = OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_item("(Select cinematic)", 0)
	picker.set_item_metadata(0, "")

	var selected_idx: int = 0
	var item_idx: int = 1

	# Use the cinematics list we already have
	for entry: Dictionary in cinematics:
		var cinematic_id: String = entry.get("name", "")
		var mod_id: String = entry.get("mod_id", "")

		var display_name: String = "[%s] %s" % [mod_id, cinematic_id] if not mod_id.is_empty() else cinematic_id
		picker.add_item(display_name, item_idx)
		picker.set_item_metadata(item_idx, cinematic_id)

		if cinematic_id == current_value:
			selected_idx = item_idx
		item_idx += 1

	picker.select(selected_idx)
	picker.item_selected.connect(_on_choice_value_picker_changed.bind(choice_index, param_name, picker))
	return picker


## Handle choice value picker selection
func _on_choice_value_picker_changed(item_index: int, choice_index: int, param_name: String, picker: OptionButton) -> void:
	if _updating_ui or selected_command_index < 0:
		return

	var value: String = picker.get_item_metadata(item_index)
	if value == null:
		value = ""

	var commands: Array = current_cinematic_data.get("commands", [])
	var params: Dictionary = commands[selected_command_index].get("params", {})

	if param_name in params and params[param_name] is Array:
		var choices: Array = params[param_name]
		if choice_index >= 0 and choice_index < choices.size():
			var choice: Variant = choices[choice_index]
			if choice is Dictionary:
				choice["value"] = value
				is_dirty = true


## Add a new choice to the list
func _on_add_choice(param_name: String, container: VBoxContainer) -> void:
	if selected_command_index < 0:
		return

	var commands: Array = current_cinematic_data.get("commands", [])
	if "params" not in commands[selected_command_index]:
		commands[selected_command_index]["params"] = {}

	var params: Dictionary = commands[selected_command_index]["params"]
	if param_name not in params or not (params[param_name] is Array):
		params[param_name] = []

	var choices: Array = params[param_name]
	var new_choice: Dictionary = {
		"label": "New choice",
		"action": "none",
		"value": ""
	}
	choices.append(new_choice)

	is_dirty = true
	# Rebuild inspector to show new choice
	_build_inspector_for_command(selected_command_index)


## Remove a choice from the list
func _on_remove_choice(index: int, param_name: String, _container: VBoxContainer) -> void:
	if selected_command_index < 0:
		return

	var commands: Array = current_cinematic_data.get("commands", [])
	var params: Dictionary = commands[selected_command_index].get("params", {})

	if param_name in params and params[param_name] is Array:
		var choices: Array = params[param_name]
		if index >= 0 and index < choices.size():
			choices.remove_at(index)
			is_dirty = true
			# Rebuild inspector
			_build_inspector_for_command(selected_command_index)


## Handle choice field text changes (label, value)
func _on_choice_field_changed(new_text: String, index: int, field: String, param_name: String) -> void:
	if _updating_ui or selected_command_index < 0:
		return

	var commands: Array = current_cinematic_data.get("commands", [])
	var params: Dictionary = commands[selected_command_index].get("params", {})

	if param_name in params and params[param_name] is Array:
		var choices: Array = params[param_name]
		if index >= 0 and index < choices.size():
			var choice: Variant = choices[index]
			if choice is Dictionary:
				choice[field] = new_text
				is_dirty = true


## Handle choice action dropdown changes
func _on_choice_action_changed(action_index: int, choice_index: int, param_name: String) -> void:
	if _updating_ui or selected_command_index < 0:
		return

	if action_index < 0 or action_index >= CHOICE_ACTIONS.size():
		return

	var new_action: String = CHOICE_ACTIONS[action_index]

	var commands: Array = current_cinematic_data.get("commands", [])
	var params: Dictionary = commands[selected_command_index].get("params", {})

	if param_name in params and params[param_name] is Array:
		var choices: Array = params[param_name]
		if choice_index >= 0 and choice_index < choices.size():
			var choice: Variant = choices[choice_index]
			if choice is Dictionary:
				choice["action"] = new_action
				is_dirty = true

				# Update placeholder text for value field
				# We need to find the value LineEdit - rebuild inspector is simpler
				_build_inspector_for_command(selected_command_index)
