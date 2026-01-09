@tool
extends JsonEditorBase

## MapMetadata Editor
## Visual editor for map configuration files (*.json in mods/*/data/maps/)
## Supports all MapMetadata properties including spawn points, connections, and type defaults
##
## Unlike resource editors, this edits JSON files directly rather than .tres resources
##
## Now extends JsonEditorBase for shared error handling, JSON operations, and mod helpers

# UI Components - Main layout
var map_list: ItemList
var detail_scroll: ScrollContainer
var detail_panel: VBoxContainer
var save_button: Button
var create_button: Button
var delete_button: Button

# Current state
var current_map_path: String = ""
var current_map_data: Dictionary = {}
var loaded_maps: Dictionary = {}  # map_id -> path for connection dropdowns

# Scene Reference section
var scene_path_edit: LineEdit
var scene_picker_button: Button
var scene_file_dialog: EditorFileDialog

# Caravan Settings section
var caravan_accessible_check: CheckBox
var caravan_visible_check: CheckBox

# Audio Settings section
var music_id_edit: LineEdit
var ambient_id_edit: LineEdit

# Edge Connections section
var edge_north_map_dropdown: OptionButton
var edge_north_spawn_edit: LineEdit
var edge_south_map_dropdown: OptionButton
var edge_south_spawn_edit: LineEdit
var edge_east_map_dropdown: OptionButton
var edge_east_spawn_edit: LineEdit
var edge_west_map_dropdown: OptionButton
var edge_west_spawn_edit: LineEdit

# New Map Dialog components
var new_map_dialog: Window
var new_map_name_edit: LineEdit
var new_map_id_edit: LineEdit
var new_map_type_dropdown: OptionButton
var new_map_tileset_dropdown: OptionButton
var new_map_create_button: Button
var new_map_cancel_button: Button
var new_map_error_label: Label

# Map type enum values (matching MapMetadata.MapType)
const MAP_TYPES: Array[String] = ["TOWN", "OVERWORLD", "DUNGEON", "BATTLE", "INTERIOR"]

# Available tilesets for new maps
var available_tilesets: Array[String] = []

# Confirmation dialog for destructive actions
var confirmation_dialog: ConfirmationDialog
var _pending_confirmation_action: Callable


func _init() -> void:
	# Configure base class settings
	resource_type_name = "Map"
	resource_dir_name = "maps"
	file_extension = ".json"

	call_deferred("_setup_ui")


func _ready() -> void:
	pass


func _setup_ui() -> void:
	# Root Control uses layout_mode = 1 with anchors in .tscn for proper TabContainer containment
	var hsplit: HSplitContainer = HSplitContainer.new()
	hsplit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hsplit.split_offset = 220
	add_child(hsplit)

	# Left side: Map list
	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var list_label: Label = Label.new()
	list_label.text = "Map Metadata Files"
	list_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	left_panel.add_child(list_label)

	var help_label: Label = Label.new()
	help_label.text = "Select a map to edit its configuration"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	left_panel.add_child(help_label)

	map_list = ItemList.new()
	map_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_list.custom_minimum_size = Vector2(0, 150)
	map_list.item_selected.connect(_on_map_selected)
	left_panel.add_child(map_list)

	var button_row: HBoxContainer = HBoxContainer.new()

	create_button = Button.new()
	create_button.text = "New Map"
	create_button.pressed.connect(_on_create_map)
	button_row.add_child(create_button)

	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_refresh_map_list)
	button_row.add_child(refresh_button)

	left_panel.add_child(button_row)

	hsplit.add_child(left_panel)

	# Right side: Detail panel in scroll container
	detail_scroll = ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.custom_minimum_size = Vector2(550, 0)
	# Ensure vertical scrolling works properly
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	detail_scroll.follow_focus = true

	detail_panel = VBoxContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_constant_override("separation", 8)

	var detail_label: Label = Label.new()
	detail_label.text = "Map Configuration"
	detail_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	detail_panel.add_child(detail_label)

	# Create all form sections (scene-as-truth: only runtime config in JSON)
	_create_scene_reference_section()
	_create_caravan_settings_section()
	_create_audio_settings_section()
	_create_edge_connections_section()

	# Error panel from base class
	var base_error_panel: PanelContainer = create_error_panel()
	detail_panel.add_child(base_error_panel)

	# Action buttons
	var action_container: HBoxContainer = HBoxContainer.new()
	action_container.add_theme_constant_override("separation", 10)

	save_button = Button.new()
	save_button.text = "Save Map Metadata"
	save_button.pressed.connect(_on_save)
	action_container.add_child(save_button)

	delete_button = Button.new()
	delete_button.text = "Delete Map"
	delete_button.pressed.connect(_on_delete)
	action_container.add_child(delete_button)

	detail_panel.add_child(action_container)

	detail_scroll.add_child(detail_panel)
	hsplit.add_child(detail_scroll)

	# Create the new map dialog
	_create_new_map_dialog()

	# Create confirmation dialog for destructive actions
	_create_confirmation_dialog()

	# Scan for available tilesets
	_scan_tilesets()

	# Initial refresh
	_refresh_map_list()


# =============================================================================
# Section Builders
# =============================================================================

func _create_scene_reference_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Scene Reference"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var path_container: HBoxContainer = HBoxContainer.new()
	var path_label: Label = Label.new()
	path_label.text = "Scene Path:"
	path_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	path_container.add_child(path_label)

	scene_path_edit = LineEdit.new()
	scene_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_path_edit.placeholder_text = "res://mods/mod_id/maps/scene.tscn"
	scene_path_edit.text_changed.connect(_on_form_field_changed)
	path_container.add_child(scene_path_edit)

	scene_picker_button = Button.new()
	scene_picker_button.text = "Browse..."
	scene_picker_button.pressed.connect(_on_browse_scene)
	path_container.add_child(scene_picker_button)

	section.add_child(path_container)

	var validation_label: Label = Label.new()
	validation_label.text = "Scene must be a .tscn file in the mods directory"
	validation_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	validation_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	section.add_child(validation_label)

	detail_panel.add_child(section)
	_add_separator()


func _create_caravan_settings_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Caravan Settings"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_text: Label = Label.new()
	help_text.text = "Controls mobile HQ visibility and interaction (SF2 feature)"
	help_text.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_text.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	section.add_child(help_text)

	caravan_accessible_check = CheckBox.new()
	caravan_accessible_check.text = "Caravan Accessible (can interact with Caravan on this map)"
	caravan_accessible_check.toggled.connect(_on_form_field_changed)
	section.add_child(caravan_accessible_check)

	caravan_visible_check = CheckBox.new()
	caravan_visible_check.text = "Caravan Visible (Caravan sprite appears on map)"
	caravan_visible_check.toggled.connect(_on_form_field_changed)
	section.add_child(caravan_visible_check)

	detail_panel.add_child(section)
	_add_separator()


func _create_audio_settings_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Audio Settings"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	music_id_edit = _create_line_edit_field("Music ID:", section, "Background music track ID")
	ambient_id_edit = _create_line_edit_field("Ambient ID:", section, "Ambient sound effect ID")

	detail_panel.add_child(section)
	_add_separator()


func _create_edge_connections_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Edge Connections"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_text: Label = Label.new()
	help_text.text = "Seamless transitions when walking off map edges (for overworld)"
	help_text.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_text.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	section.add_child(help_text)

	# North edge
	var north_container: HBoxContainer = HBoxContainer.new()
	var north_label: Label = Label.new()
	north_label.text = "North:"
	north_label.custom_minimum_size.x = 60
	north_container.add_child(north_label)
	edge_north_map_dropdown = OptionButton.new()
	edge_north_map_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edge_north_map_dropdown.item_selected.connect(_on_form_field_changed)
	north_container.add_child(edge_north_map_dropdown)
	var north_spawn_label: Label = Label.new()
	north_spawn_label.text = "Spawn:"
	north_container.add_child(north_spawn_label)
	edge_north_spawn_edit = LineEdit.new()
	edge_north_spawn_edit.custom_minimum_size.x = 100
	edge_north_spawn_edit.text_changed.connect(_on_form_field_changed)
	north_container.add_child(edge_north_spawn_edit)
	section.add_child(north_container)

	# South edge
	var south_container: HBoxContainer = HBoxContainer.new()
	var south_label: Label = Label.new()
	south_label.text = "South:"
	south_label.custom_minimum_size.x = 60
	south_container.add_child(south_label)
	edge_south_map_dropdown = OptionButton.new()
	edge_south_map_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edge_south_map_dropdown.item_selected.connect(_on_form_field_changed)
	south_container.add_child(edge_south_map_dropdown)
	var south_spawn_label: Label = Label.new()
	south_spawn_label.text = "Spawn:"
	south_container.add_child(south_spawn_label)
	edge_south_spawn_edit = LineEdit.new()
	edge_south_spawn_edit.custom_minimum_size.x = 100
	edge_south_spawn_edit.text_changed.connect(_on_form_field_changed)
	south_container.add_child(edge_south_spawn_edit)
	section.add_child(south_container)

	# East edge
	var east_container: HBoxContainer = HBoxContainer.new()
	var east_label: Label = Label.new()
	east_label.text = "East:"
	east_label.custom_minimum_size.x = 60
	east_container.add_child(east_label)
	edge_east_map_dropdown = OptionButton.new()
	edge_east_map_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edge_east_map_dropdown.item_selected.connect(_on_form_field_changed)
	east_container.add_child(edge_east_map_dropdown)
	var east_spawn_label: Label = Label.new()
	east_spawn_label.text = "Spawn:"
	east_container.add_child(east_spawn_label)
	edge_east_spawn_edit = LineEdit.new()
	edge_east_spawn_edit.custom_minimum_size.x = 100
	edge_east_spawn_edit.text_changed.connect(_on_form_field_changed)
	east_container.add_child(edge_east_spawn_edit)
	section.add_child(east_container)

	# West edge
	var west_container: HBoxContainer = HBoxContainer.new()
	var west_label: Label = Label.new()
	west_label.text = "West:"
	west_label.custom_minimum_size.x = 60
	west_container.add_child(west_label)
	edge_west_map_dropdown = OptionButton.new()
	edge_west_map_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edge_west_map_dropdown.item_selected.connect(_on_form_field_changed)
	west_container.add_child(edge_west_map_dropdown)
	var west_spawn_label: Label = Label.new()
	west_spawn_label.text = "Spawn:"
	west_container.add_child(west_spawn_label)
	edge_west_spawn_edit = LineEdit.new()
	edge_west_spawn_edit.custom_minimum_size.x = 100
	edge_west_spawn_edit.text_changed.connect(_on_form_field_changed)
	west_container.add_child(edge_west_spawn_edit)
	section.add_child(west_container)

	detail_panel.add_child(section)
	_add_separator()


func _create_new_map_dialog() -> void:
	new_map_dialog = Window.new()
	new_map_dialog.title = "Create New Map"
	new_map_dialog.size = Vector2i(450, 400)
	new_map_dialog.transient = true
	new_map_dialog.exclusive = true
	new_map_dialog.visible = false
	new_map_dialog.close_requested.connect(_on_new_map_dialog_close)
	add_child(new_map_dialog)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	new_map_dialog.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title
	var title_label: Label = Label.new()
	title_label.text = "Create a new map with scene, script, and metadata"
	title_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	vbox.add_child(title_label)

	# Map Name
	var name_row: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Map Name:"
	name_label.custom_minimum_size.x = 100
	name_row.add_child(name_label)
	new_map_name_edit = LineEdit.new()
	new_map_name_edit.placeholder_text = "My Town"
	new_map_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_map_name_edit.text_changed.connect(_on_new_map_name_changed)
	name_row.add_child(new_map_name_edit)
	vbox.add_child(name_row)

	# Map ID (auto-generated)
	var id_row: HBoxContainer = HBoxContainer.new()
	var id_label: Label = Label.new()
	id_label.text = "Map ID:"
	id_label.custom_minimum_size.x = 100
	id_row.add_child(id_label)
	new_map_id_edit = LineEdit.new()
	new_map_id_edit.placeholder_text = "mod_id:my_town"
	new_map_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_map_id_edit.editable = true
	id_row.add_child(new_map_id_edit)
	vbox.add_child(id_row)

	# Map Type
	var type_row: HBoxContainer = HBoxContainer.new()
	var type_label: Label = Label.new()
	type_label.text = "Map Type:"
	type_label.custom_minimum_size.x = 100
	type_row.add_child(type_label)
	new_map_type_dropdown = OptionButton.new()
	new_map_type_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for map_type: String in MAP_TYPES:
		new_map_type_dropdown.add_item(map_type)
	type_row.add_child(new_map_type_dropdown)
	vbox.add_child(type_row)

	# Tileset
	var tileset_row: HBoxContainer = HBoxContainer.new()
	var tileset_label: Label = Label.new()
	tileset_label.text = "Tileset:"
	tileset_label.custom_minimum_size.x = 100
	tileset_row.add_child(tileset_label)
	new_map_tileset_dropdown = OptionButton.new()
	new_map_tileset_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tileset_row.add_child(new_map_tileset_dropdown)
	vbox.add_child(tileset_row)

	# Info text
	var info_label: Label = Label.new()
	info_label.text = "This will create:\n* maps/<name>.gd - Map script\n* maps/<name>.tscn - Map scene\n* data/maps/<name>.json - Metadata"
	info_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	info_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(info_label)

	# Error label (hidden by default)
	new_map_error_label = Label.new()
	new_map_error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	new_map_error_label.visible = false
	new_map_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(new_map_error_label)

	# Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Buttons
	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 10)

	new_map_cancel_button = Button.new()
	new_map_cancel_button.text = "Cancel"
	new_map_cancel_button.pressed.connect(_on_new_map_dialog_close)
	button_row.add_child(new_map_cancel_button)

	new_map_create_button = Button.new()
	new_map_create_button.text = "Create Map"
	new_map_create_button.pressed.connect(_on_confirm_create_map)
	button_row.add_child(new_map_create_button)

	vbox.add_child(button_row)


# =============================================================================
# Confirmation Dialog
# =============================================================================

func _create_confirmation_dialog() -> void:
	confirmation_dialog = ConfirmationDialog.new()
	confirmation_dialog.title = "Confirm Action"
	confirmation_dialog.confirmed.connect(_on_confirmation_confirmed)
	add_child(confirmation_dialog)


func _show_confirmation(title: String, message: String, on_confirm: Callable) -> void:
	confirmation_dialog.title = title
	confirmation_dialog.dialog_text = message
	_pending_confirmation_action = on_confirm
	confirmation_dialog.popup_centered()


func _on_confirmation_confirmed() -> void:
	if _pending_confirmation_action.is_valid():
		_pending_confirmation_action.call()
	_pending_confirmation_action = Callable()


# =============================================================================
# Helper Functions
# =============================================================================

func _create_line_edit_field(label_text: String, parent: VBoxContainer, tooltip: String = "") -> LineEdit:
	var container: HBoxContainer = HBoxContainer.new()

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	if tooltip != "":
		label.tooltip_text = tooltip
	container.add_child(label)

	var edit: LineEdit = LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tooltip != "":
		edit.tooltip_text = tooltip
	edit.text_changed.connect(_on_form_field_changed)
	container.add_child(edit)

	parent.add_child(container)
	return edit


func _add_separator() -> void:
	var sep: HSeparator = HSeparator.new()
	sep.custom_minimum_size.y = 10
	detail_panel.add_child(sep)


## Called when any form field changes to mark the editor as dirty
func _on_form_field_changed(_value: Variant = null) -> void:
	is_dirty = true


# =============================================================================
# Public refresh method (standard interface)
# =============================================================================

## Public refresh method for standard editor interface
func refresh() -> void:
	_refresh_map_list()


# =============================================================================
# Map List Management
# =============================================================================

func _refresh_map_list() -> void:
	map_list.clear()
	loaded_maps.clear()

	# Use base class scanning to find all map metadata files
	var resources: Array[Dictionary] = scan_all_mods_for_resources()

	for res_info: Dictionary in resources:
		var mod_id: String = res_info.get("mod_id", "")
		var path: String = res_info.get("path", "")
		var resource_id: String = res_info.get("resource_id", "")

		# Try to load the map_id from the JSON file
		var map_id: String = _load_map_id_from_file(path)
		if map_id.is_empty():
			map_id = resource_id

		var display_text: String = "[%s] %s" % [mod_id, map_id]
		map_list.add_item(display_text)
		map_list.set_item_metadata(map_list.item_count - 1, path)

		loaded_maps[map_id] = path

	# Update connection dropdowns with loaded maps
	_update_map_dropdowns()


func _load_map_id_from_file(path: String) -> String:
	var json_text: String = FileAccess.get_file_as_string(path)
	if json_text.is_empty():
		return ""

	var json_data: Variant = JSON.parse_string(json_text)
	if json_data is Dictionary:
		return json_data.get("map_id", "")

	return ""


func _update_map_dropdowns() -> void:
	# Clear and repopulate edge connection map dropdowns
	var dropdowns: Array[OptionButton] = [
		edge_north_map_dropdown,
		edge_south_map_dropdown,
		edge_east_map_dropdown,
		edge_west_map_dropdown
	]

	for dropdown in dropdowns:
		if dropdown:
			dropdown.clear()
			dropdown.add_item("(None)")
			for map_id in loaded_maps.keys():
				dropdown.add_item(map_id)


# =============================================================================
# Map Selection and Loading
# =============================================================================

func _on_map_selected(index: int) -> void:
	var path: String = map_list.get_item_metadata(index)
	_load_map_json(path)


func _load_map_json(path: String) -> void:
	current_map_path = path

	# Use base class JSON loading
	var json_data: Dictionary = load_json_file(path)
	if json_data.is_empty():
		return  # Error already shown by base class

	current_map_data = json_data
	_populate_ui_from_data()
	_hide_errors()
	is_dirty = false


func _populate_ui_from_data() -> void:
	# Scene reference (REQUIRED - the only mandatory field in scene-as-truth)
	scene_path_edit.text = current_map_data.get("scene_path", "")

	# Caravan settings (runtime config)
	caravan_accessible_check.button_pressed = current_map_data.get("caravan_accessible", false)
	caravan_visible_check.button_pressed = current_map_data.get("caravan_visible", false)

	# Audio settings (runtime config)
	music_id_edit.text = current_map_data.get("music_id", "")
	ambient_id_edit.text = current_map_data.get("ambient_id", "")

	# Edge connections (overworld only - cannot derive from scene)
	_populate_edge_connections()


func _populate_edge_connections() -> void:
	var edge_connections: Dictionary = current_map_data.get("edge_connections", {})

	_set_edge_dropdown_value(edge_north_map_dropdown, edge_north_spawn_edit, edge_connections.get("north", {}))
	_set_edge_dropdown_value(edge_south_map_dropdown, edge_south_spawn_edit, edge_connections.get("south", {}))
	_set_edge_dropdown_value(edge_east_map_dropdown, edge_east_spawn_edit, edge_connections.get("east", {}))
	_set_edge_dropdown_value(edge_west_map_dropdown, edge_west_spawn_edit, edge_connections.get("west", {}))


func _set_edge_dropdown_value(dropdown: OptionButton, spawn_edit: LineEdit, edge_data: Dictionary) -> void:
	var target_map: String = edge_data.get("target_map_id", "")
	var target_spawn: String = edge_data.get("target_spawn_id", "")

	spawn_edit.text = target_spawn

	if target_map.is_empty():
		dropdown.select(0)  # (None)
	else:
		for i in range(dropdown.item_count):
			if dropdown.get_item_text(i) == target_map:
				dropdown.select(i)
				return
		dropdown.select(0)


# =============================================================================
# Data Collection
# =============================================================================

func _collect_data_from_ui() -> void:
	# Scene reference (REQUIRED - the only mandatory field with scene-as-truth)
	current_map_data["scene_path"] = scene_path_edit.text

	# Caravan settings (runtime config)
	current_map_data["caravan_accessible"] = caravan_accessible_check.button_pressed
	current_map_data["caravan_visible"] = caravan_visible_check.button_pressed

	# Audio settings (runtime config)
	current_map_data["music_id"] = music_id_edit.text
	current_map_data["ambient_id"] = ambient_id_edit.text

	# Edge connections (overworld only - cannot derive from scene)
	var edge_connections: Dictionary = {}
	_collect_edge_connection(edge_connections, "north", edge_north_map_dropdown, edge_north_spawn_edit)
	_collect_edge_connection(edge_connections, "south", edge_south_map_dropdown, edge_south_spawn_edit)
	_collect_edge_connection(edge_connections, "east", edge_east_map_dropdown, edge_east_spawn_edit)
	_collect_edge_connection(edge_connections, "west", edge_west_map_dropdown, edge_west_spawn_edit)
	current_map_data["edge_connections"] = edge_connections


func _collect_edge_connection(edge_connections: Dictionary, direction: String, dropdown: OptionButton, spawn_edit: LineEdit) -> void:
	if dropdown.selected > 0:  # Not "(None)"
		var target_map: String = dropdown.get_item_text(dropdown.selected)
		var target_spawn: String = spawn_edit.text.strip_edges()
		if not target_map.is_empty():
			edge_connections[direction] = {
				"target_map_id": target_map,
				"target_spawn_id": target_spawn,
				"overlap_tiles": 1
			}


# =============================================================================
# Save and Delete Operations
# =============================================================================

func _on_save() -> void:
	if current_map_path.is_empty():
		_show_errors(["No map selected"])
		return

	# Validate
	var errors: Array[String] = _validate_map_data()
	if errors.size() > 0:
		_show_errors(errors)
		return

	# Collect data from UI
	_collect_data_from_ui()

	# Use base class JSON saving
	if not save_json_file(current_map_path, current_map_data):
		return  # Error already shown by base class

	_hide_errors()
	is_dirty = false

	# Refresh map list to show updated info
	_refresh_map_list()

	# Notify that a map was saved
	var map_id: String = current_map_data.get("map_id", "")
	notify_resource_saved(map_id)


func _on_delete() -> void:
	if current_map_path.is_empty():
		_show_errors(["No map selected"])
		return

	var map_id: String = current_map_data.get("map_id", "unknown")
	var scene_path: String = current_map_data.get("scene_path", "")

	var message: String = "Are you sure you want to delete map '%s'?\n\n" % map_id
	message += "This will permanently delete:\n"
	message += "  - Map metadata file (.json)\n"
	if not scene_path.is_empty() and FileAccess.file_exists(scene_path):
		message += "  - Map scene file (.tscn)\n"
		var script_path: String = scene_path.replace(".tscn", ".gd")
		if FileAccess.file_exists(script_path):
			message += "  - Map script file (.gd)\n"
	message += "\nThis action cannot be undone."

	_show_confirmation("Delete Map", message, _perform_delete)


func _perform_delete() -> void:
	# Delete the JSON metadata file
	var err: Error = DirAccess.remove_absolute(current_map_path)
	if err != OK:
		_show_errors(["Failed to delete map file: " + error_string(err)])
		return

	# Also delete associated scene and script files if they exist
	var scene_path: String = current_map_data.get("scene_path", "")
	if not scene_path.is_empty() and FileAccess.file_exists(scene_path):
		var scene_err: Error = DirAccess.remove_absolute(scene_path)
		if scene_err != OK:
			push_warning("Failed to delete scene file: %s" % scene_path)

		# Try to delete the script file too (same name, .gd extension)
		var script_path: String = scene_path.replace(".tscn", ".gd")
		if FileAccess.file_exists(script_path):
			var script_err: Error = DirAccess.remove_absolute(script_path)
			if script_err != OK:
				push_warning("Failed to delete script file: %s" % script_path)

	# Notify that the map was deleted
	var map_id: String = current_map_data.get("map_id", "")
	if not map_id.is_empty():
		notify_resource_deleted(map_id)

	current_map_path = ""
	current_map_data = {}
	_clear_ui()
	_refresh_map_list()
	_hide_errors()


func _on_create_map() -> void:
	# Show the new map dialog instead of directly creating files
	_show_new_map_dialog()


func _show_new_map_dialog() -> void:
	# Reset dialog fields
	new_map_name_edit.text = ""
	new_map_id_edit.text = ""
	new_map_type_dropdown.select(0)  # Default to TOWN
	_hide_dialog_error()

	# Set default map ID prefix from active mod
	var active_mod_id: String = SparklingEditorUtils.get_active_mod_id()
	new_map_id_edit.placeholder_text = "%s:map_name" % active_mod_id

	# Refresh tileset dropdown
	_refresh_tileset_dropdown()

	# Show dialog
	new_map_dialog.popup_centered()


func _show_dialog_error(message: String) -> void:
	new_map_error_label.text = message
	new_map_error_label.visible = true


func _hide_dialog_error() -> void:
	new_map_error_label.text = ""
	new_map_error_label.visible = false


func _on_new_map_name_changed(new_name: String) -> void:
	# Auto-generate map ID from name
	var active_mod_id: String = SparklingEditorUtils.get_active_mod_id()
	var clean_id: String = SparklingEditorUtils.generate_id_from_name(new_name)
	new_map_id_edit.text = "%s:%s" % [active_mod_id, clean_id]


func _on_new_map_dialog_close() -> void:
	new_map_dialog.hide()


func _scan_tilesets() -> void:
	available_tilesets.clear()

	# First, add core default tileset (always available as fallback)
	var core_tileset_path: String = "res://core/defaults/tilesets/default_tileset.tres"
	if ResourceLoader.exists(core_tileset_path):
		available_tilesets.append(core_tileset_path)

	# Use the Tileset Registry for discovery (supports mod.json declarations + auto-discovery)
	if ModLoader and ModLoader.tileset_registry:
		var registry_tilesets: Array[String] = ModLoader.tileset_registry.get_all_tileset_paths()
		for tileset_path: String in registry_tilesets:
			if tileset_path not in available_tilesets:
				available_tilesets.append(tileset_path)
	else:
		# Fallback: Scan for .tres files in tileset directories across mods
		var results: Array[Dictionary] = SparklingEditorUtils.scan_mods_for_files("tilesets", ".tres")
		for res: Dictionary in results:
			var path: String = res.get("path", "")
			# Verify it's actually a TileSet resource and not already added
			if ResourceLoader.exists(path) and path not in available_tilesets:
				available_tilesets.append(path)

	if available_tilesets.is_empty():
		push_warning("MapMetadataEditor: No tilesets found. Core default should exist at res://core/defaults/tilesets/")


func _refresh_tileset_dropdown() -> void:
	new_map_tileset_dropdown.clear()

	# Use registry for display names if available
	for tileset_path: String in available_tilesets:
		var display_name: String = ""
		# Try to get display name from registry
		if ModLoader and ModLoader.tileset_registry:
			var tileset_id: String = tileset_path.get_file().get_basename().to_lower()
			var info: Dictionary = ModLoader.tileset_registry.get_tileset_info(tileset_id)
			display_name = info.get("display_name", "")
		# Fallback to extracting from filename
		if display_name.is_empty():
			display_name = tileset_path.get_file().get_basename()
		new_map_tileset_dropdown.add_item(display_name)
		new_map_tileset_dropdown.set_item_metadata(new_map_tileset_dropdown.item_count - 1, tileset_path)


func _on_confirm_create_map() -> void:
	var map_name: String = new_map_name_edit.text.strip_edges()
	var map_id: String = new_map_id_edit.text.strip_edges()
	var map_type: String = MAP_TYPES[new_map_type_dropdown.selected]

	# Validation
	if map_name.is_empty():
		_show_dialog_error("Map name cannot be empty")
		return
	if map_id.is_empty() or ":" not in map_id:
		_show_dialog_error("Map ID must be in format 'mod_id:map_name'")
		return

	# Get selected tileset
	var tileset_path: String = ""
	if new_map_tileset_dropdown.selected >= 0:
		var metadata: Variant = new_map_tileset_dropdown.get_item_metadata(new_map_tileset_dropdown.selected)
		if metadata != null:
			tileset_path = metadata

	# Validate tileset selection - don't require a specific mod's tileset
	if tileset_path.is_empty():
		_show_dialog_error("Please select a tileset. If none are available, create one in your mod's tilesets/ directory.")
		return

	# Determine active mod
	var active_mod_id: String = SparklingEditorUtils.get_active_mod_id()
	var mod_dir: String = SparklingEditorUtils.get_active_mod_path()

	if active_mod_id.is_empty() or mod_dir.is_empty():
		_show_dialog_error("No active mod selected. Please select a mod from the Active Mod dropdown before creating a map.")
		return

	# Generate file name from map_name
	var clean_base: String = SparklingEditorUtils.generate_id_from_name(map_name)
	if clean_base.is_empty():
		clean_base = "new_map"

	# Define file paths
	var maps_dir: String = mod_dir.path_join("maps/")
	var data_maps_dir: String = mod_dir.path_join("data/maps/")

	var script_path: String = maps_dir + clean_base + ".gd"
	var scene_path: String = maps_dir + clean_base + ".tscn"
	var json_path: String = data_maps_dir + clean_base + ".json"

	# Check for existing files
	if FileAccess.file_exists(script_path) or FileAccess.file_exists(scene_path) or FileAccess.file_exists(json_path):
		_show_dialog_error("A map with name '%s' already exists in this mod" % clean_base)
		return

	# Create directories if needed
	if not SparklingEditorUtils.ensure_directory_exists(maps_dir):
		_show_dialog_error("Failed to create maps directory")
		return

	if not SparklingEditorUtils.ensure_directory_exists(data_maps_dir):
		_show_dialog_error("Failed to create data/maps directory")
		return

	# Generate and save all files
	var script_content: String = _generate_map_script(map_id, map_name, map_type)
	var scene_content: String = _generate_map_scene(clean_base, script_path, tileset_path, map_id, map_name, map_type)
	var json_content: String = _generate_map_json(scene_path)

	# Write script file
	var script_file: FileAccess = FileAccess.open(script_path, FileAccess.WRITE)
	if not script_file:
		_show_dialog_error("Failed to create script file: " + script_path)
		return
	script_file.store_string(script_content)
	script_file.close()

	# Write scene file
	var scene_file: FileAccess = FileAccess.open(scene_path, FileAccess.WRITE)
	if not scene_file:
		_show_dialog_error("Failed to create scene file: " + scene_path)
		return
	scene_file.store_string(scene_content)
	scene_file.close()

	# Write JSON file
	var json_file: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	if not json_file:
		_show_dialog_error("Failed to create JSON file: " + json_path)
		return
	json_file.store_string(json_content)
	json_file.close()

	# Close dialog
	new_map_dialog.hide()

	# Refresh map list
	_refresh_map_list()

	# Select the new map
	for i in range(map_list.item_count):
		var path: String = map_list.get_item_metadata(i)
		if path == json_path:
			map_list.select(i)
			_on_map_selected(i)
			break

	_hide_errors()

	# Dynamically register the new map with ModLoader.registry so it's immediately available
	# (without requiring a full mod reload)
	if ModLoader and ModLoader.registry:
		var MapMetadataLoader: GDScript = load("res://core/systems/map_metadata_loader.gd")
		if MapMetadataLoader:
			var map_res: Resource = MapMetadataLoader.load_from_json(json_path)
			if map_res:
				ModLoader.registry.register_resource(map_res, "map", map_id, active_mod_id)

	# Notify EditorEventBus so other panels (like CinematicEditor) refresh their dropdowns
	notify_resource_created(map_id)


func _generate_map_script(p_map_id: String, p_map_name: String, p_map_type: String) -> String:
	# Battle maps use a minimal script - BattleLoader handles everything
	if p_map_type == "BATTLE":
		return _generate_battle_map_script(p_map_id, p_map_name)

	# Build script content with string concatenation to avoid % formatting issues
	var lines: PackedStringArray = PackedStringArray()
	lines.append('extends "res://core/templates/map_template.gd"')
	lines.append("")
	lines.append("# =============================================================================")
	lines.append("# MAP IDENTITY (Scene as Source of Truth)")
	lines.append("# =============================================================================")
	lines.append("")
	lines.append('## Unique identifier for this map (namespaced: "mod_id:map_name")')
	lines.append('@export var map_id: String = "%s"' % p_map_id)
	lines.append("")
	lines.append("## Map type determines Caravan visibility and party follower behavior")
	lines.append('@export_enum("TOWN", "OVERWORLD", "DUNGEON", "INTERIOR", "BATTLE") var map_type: String = "%s"' % p_map_type)
	lines.append("")
	lines.append("## Display name for UI (save menu, map name popups)")
	lines.append('@export var display_name: String = "%s"' % p_map_name)
	lines.append("")
	lines.append("")
	lines.append("# =============================================================================")
	lines.append("# LIFECYCLE")
	lines.append("# =============================================================================")
	lines.append("")
	lines.append("func _ready() -> void:")
	lines.append("\tsuper._ready()")
	lines.append('\t_debug_print("Map \'%s\' ready!" % display_name)')
	lines.append("")

	return "\n".join(lines)


## Generate a minimal script for battle maps
## Battle maps don't need exploration features - BattleLoader handles everything
func _generate_battle_map_script(p_map_id: String, p_map_name: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("extends Node2D")
	lines.append("")
	lines.append("## Battle map - minimal script for BattleLoader compatibility")
	lines.append("## Battle maps don't need exploration features (party followers, camera, etc.)")
	lines.append("## The BattleLoader handles all battle-specific setup")
	lines.append("")
	lines.append('@export var map_id: String = "%s"' % p_map_id)
	lines.append('@export_enum("TOWN", "OVERWORLD", "DUNGEON", "INTERIOR", "BATTLE") var map_type: String = "BATTLE"')
	lines.append('@export var display_name: String = "%s"' % p_map_name)
	lines.append("")

	return "\n".join(lines)


func _generate_map_scene(node_name: String, script_path: String, tileset_path: String, map_id: String, map_name: String, map_type: String) -> String:
	# Capitalize node name
	var capitalized_name: String = ""
	var capitalize_next: bool = true
	for c: String in node_name:
		if c == "_":
			capitalize_next = true
		elif capitalize_next:
			capitalized_name += c.to_upper()
			capitalize_next = false
		else:
			capitalized_name += c

	if capitalized_name.is_empty():
		capitalized_name = "NewMap"

	# Battle maps need a different structure for BattleLoader compatibility
	if map_type == "BATTLE":
		return _generate_battle_map_scene(capitalized_name, script_path, tileset_path, map_id, map_name)

	var scene: String = """[gd_scene load_steps=5 format=4]

[ext_resource type="Script" path="%s" id="1_script"]
[ext_resource type="TileSet" path="%s" id="2_tileset"]
[ext_resource type="Script" uid="uid://iijt33alqt3j" path="res://scenes/map_exploration/map_camera.gd" id="3_camera"]
[ext_resource type="Script" uid="uid://cvr41yel2uyjd" path="res://core/components/spawn_point.gd" id="4_spawn"]

[node name="%s" type="Node2D"]
script = ExtResource("1_script")
map_id = "%s"
map_type = "%s"
display_name = "%s"

[node name="TileMapLayer" type="TileMapLayer" parent="."]
tile_set = ExtResource("2_tileset")

[node name="SpawnPoints" type="Node2D" parent="."]

[node name="DefaultStart" type="Marker2D" parent="SpawnPoints"]
position = Vector2(176, 176)
script = ExtResource("4_spawn")
spawn_id = "default_start"
is_default = true
description = "Default starting position"

[node name="Followers" type="Node2D" parent="."]

[node name="MapCamera" type="Camera2D" parent="."]
position = Vector2(176, 176)
script = ExtResource("3_camera")

[node name="Triggers" type="Node2D" parent="."]
""" % [script_path, tileset_path, capitalized_name, map_id, map_type, map_name]

	return scene


## Generate a battle map scene with BattleLoader-compatible structure
## Battle maps need: Map/GroundLayer, Map/HighlightLayer for grid-based combat
func _generate_battle_map_scene(capitalized_name: String, script_path: String, tileset_path: String, map_id: String, map_name: String) -> String:
	var scene: String = """[gd_scene load_steps=4 format=4]

[ext_resource type="Script" path="%s" id="1_script"]
[ext_resource type="TileSet" path="%s" id="2_tileset"]
[ext_resource type="TileSet" uid="uid://c8kv3jx2wr7pb" path="res://assets/tilesets/highlight_tileset.tres" id="3_highlight"]

[node name="%s" type="Node2D"]
script = ExtResource("1_script")
map_id = "%s"
map_type = "BATTLE"
display_name = "%s"

[node name="Map" type="Node2D" parent="."]

[node name="GroundLayer" type="TileMapLayer" parent="Map"]
tile_set = ExtResource("2_tileset")

[node name="HighlightLayer" type="TileMapLayer" parent="Map"]
z_index = 1
tile_set = ExtResource("3_highlight")
""" % [script_path, tileset_path, capitalized_name, map_id, map_name]

	return scene


func _generate_map_json(scene_path: String) -> String:
	var json_data: Dictionary = {
		"scene_path": scene_path
	}
	return JSON.stringify(json_data, "\t") + "\n"


func _clear_ui() -> void:
	scene_path_edit.text = ""
	caravan_accessible_check.button_pressed = false
	caravan_visible_check.button_pressed = false
	music_id_edit.text = ""
	ambient_id_edit.text = ""
	edge_north_map_dropdown.select(0)
	edge_north_spawn_edit.text = ""
	edge_south_map_dropdown.select(0)
	edge_south_spawn_edit.text = ""
	edge_east_map_dropdown.select(0)
	edge_east_spawn_edit.text = ""
	edge_west_map_dropdown.select(0)
	edge_west_spawn_edit.text = ""


# =============================================================================
# Validation
# =============================================================================

func _validate_map_data() -> Array[String]:
	var errors: Array[String] = []

	# Scene path is REQUIRED - the only mandatory field with scene-as-truth
	var scene_path: String = scene_path_edit.text.strip_edges()
	if scene_path.is_empty():
		errors.append("Scene path is required")
	elif not scene_path.ends_with(".tscn"):
		errors.append("Scene path must be a .tscn file")
	elif not FileAccess.file_exists(scene_path):
		errors.append("Scene file does not exist: " + scene_path)

	# Map ID, display_name, spawn points are all in scene now (scene-as-truth)

	# Check Caravan consistency
	if caravan_visible_check.button_pressed and not caravan_accessible_check.button_pressed:
		errors.append("Caravan visible requires Caravan accessible")

	return errors


# =============================================================================
# Event Handlers
# =============================================================================

func _on_browse_scene() -> void:
	if not scene_file_dialog:
		scene_file_dialog = EditorFileDialog.new()
		scene_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		scene_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		scene_file_dialog.filters = PackedStringArray(["*.tscn ; Scene Files"])
		if not scene_file_dialog.file_selected.is_connected(_on_scene_file_selected):
			scene_file_dialog.file_selected.connect(_on_scene_file_selected)
		add_child(scene_file_dialog)

	# Default to active mod's maps directory if available
	var default_path: String = "res://mods/"
	if ModLoader:
		var active_mod: ModManifest = ModLoader.get_active_mod()
		if active_mod:
			var maps_dir: String = "res://mods/%s/maps/" % active_mod.mod_id
			if DirAccess.dir_exists_absolute(maps_dir):
				default_path = maps_dir

	scene_file_dialog.current_dir = default_path
	scene_file_dialog.popup_centered_ratio(0.7)


func _on_scene_file_selected(path: String) -> void:
	scene_path_edit.text = path
	is_dirty = true
